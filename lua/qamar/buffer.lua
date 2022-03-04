local function copy_transaction(self)
    return vim.tbl_extend('force', {}, self)
end

local function new_transaction()
    local ret
    ret = {
        index = 0,
        fileIndex = 0,
        row = 0,
        col = 0,
        copy = function()
            copy_transaction(ret)
        end,
    }
    return ret
end

---comment Create a buffered iterator reader
---@param input function An iterator which provides utf-8 codepoints
local buffer = function(input)
    if type(input) ~= 'function' then
        return nil, 'expected a function as input'
    end
    do
        local _input
        input = function()
            local ret = _input()
            if ret == nil then
                return ''
            elseif type(ret) ~= 'string' or ret == '' then
                error 'iterator must return non-empty string or nil'
            end
            return ret
        end
    end
    local lookahead = {}
    local transactions = {}
    local closed = false
    local s = new_transaction()

    local function hasNoTransactions()
        return #transactions == 0
    end

    local function lookaheadBufferSize()
        return #lookahead
    end

    local function normalizeLookaheadBuffer()
        if hasNoTransactions() and s.index > 0 then
            local available = lookaheadBufferSize() - s.index
            for i = 0, available - 1 do
                lookahead[i + 1] = lookahead[s.index + i + 1]
            end
            local newsize = lookaheadBufferSize() - s.index
            s.index = 0
            while #lookahead > newsize do
                table.remove(lookahead)
            end
        end
    end

    local function updateRowCol(c)
        if c == '\n' then
            s.row, s.col = s.row + 1, 0
        else
            s.col = s.col + 1
        end
    end

    local ret = {}
    function ret.location()
        return { fileIndex = s.fileIndex, row = s.row, col = s.col }
    end

    function ret.begin()
        normalizeLookaheadBuffer()
        table.insert(transactions, s)
        s = s.copy()
    end

    function ret.undo()
        if hasNoTransactions() then
            error 'no transactions to roll back'
        end
        s = table.remove(transactions)
        normalizeLookaheadBuffer()
    end

    function ret.commit()
        if hasNoTransactions() then
            error 'no transactions to roll back'
        end
        table.remove(transactions)
        normalizeLookaheadBuffer()
    end

    function ret.peek(amt)
        if amt == nil then
            amt = 0
        end
    end

    function ret.take(amt)
        if amt == nil then
            if hasNoTransactions() then
                if s.index < lookaheadBufferSize() then
                    local c = lookahead[s.index + 1]
                    if c == '' then
                        return -1
                    end
                    s.index, s.fileIndex = s.index + 1, s.fileIndex + 1
                    updateRowCol(c)
                    return c
                elseif input.hasNext() then
                    s.fileIndex = s.fileIndex + 1
                    local c = input()
                    updateRowCol(c)
                    return c
                else
                    return -1
                end
            elseif s.index < lookaheadBufferSize() then
                local c = lookahead[s.index + 1]
                if c == '' then
                    return -1
                end
                updateRowCol(c)
                s.index, s.fileIndex = s.index + 1, s.fileIndex + 1
                return c
            elseif input.hasNext() then
                local c = input()
                updateRowCol(c)
                table.insert(lookahead, c)
                s.index, s.fileIndex = s.index + 1, s.fileIndex + 1
                return c
            else
                table.insert(lookahead, -1)
                return -1
            end
        else
            if ret.peek(amt - 1) ~= '' then
                return false
            end
            for _ = 1, amt do
                ret.take()
            end
            return true
        end
    end

    function ret.takech(amt)
        if ret.peek(amt - 1) ~= '' then
            local r = {}
            for _ = amt, 1, -1 do
                table.insert(r, ret.take())
            end
            return table.concat(r)
        end
    end

    function ret.takeUntil(fileIndex)
        while s.fileIndex < fileIndex do
            if ret.peek() == '' then
                return false
            end
            ret.take()
        end
        return true
    end

    return ret
end

local java = [[
public class CodePointTransactionalBuffer implements AutoCloseable {
	private void populateLookaheadBuffer(final int targetSize) {
		while (lookaheadBufferSize() < targetSize) {
			if (input.hasNext())
				lookahead.add(input.next());
			else {
				if (lookahead.size() == 0 || lookahead.get(lookahead.size() - 1) != -1)
					lookahead.add(-1);
				break;
			}
		}
	}

	public int peek(final int skip) {
		normalizeLookaheadBuffer();
		final var targetIndex = s.index + skip;
		if (targetIndex < lookaheadBufferSize())
			return lookahead.get(targetIndex);
		else {
			populateLookaheadBuffer(targetIndex + 1);
			if (targetIndex >= lookaheadBufferSize())
				return -1;
			else
				return lookahead.get(targetIndex);
		}
	}

	public void skipws() {
		while (true) {
			final var c = peek();
			if (c != ' ' && c != '\t' && c != '\r' && c != '\n')
				break;
			take();
		}
	}

	public boolean tryConsumeString(final String s, final Function<Integer, Boolean> predicate) {
		if (s == null)
			throw new NullPointerException();
		if (s.length() == 0)
			return true;
		int loc = 0;
		for (final int c : s.codePoints().toArray())
			if (peek(loc++) != c)
				return false;
		if (predicate != null && !predicate.apply(loc))
			return false;
		take(loc);
		return true;
	}

	public boolean tryConsumeString(final String s) {
		return tryConsumeString(s, null);
	}

	public int peek() {
		return peek(0);
	}

	@Override
	public void close() throws Exception {
		if (closed)
			return;
		lookahead.clear();
		lookahead.add(-1);
		s.index = 0;
		closed = true;
	}

	public boolean isEof() {
		return peek() == '';
	}

	@Override
	public String toString() {
		final var sb = new StringBuilder();
		for (var i = 0; i < lookaheadBufferSize(); ++i) {
			sb.append("\n");
			sb.append(i == s.index ? "==> " : "    ");
			final var st = lookahead.get(i);
			if (st == null)
				sb.append("~~ EOF ~~");
			else if (st >= 32 && st < 127)
				sb.append('\'').appendCodePoint(st).append('\'');
			else
				sb.append(st);
		}
		if (s.index == lookaheadBufferSize())
			sb.append("\n").append("==> ");
		sb.append('\n');
		return sb.toString();
	}
}
]]
return buffer
