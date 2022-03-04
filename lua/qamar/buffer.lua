local function copy_transaction(self)
    return vim.tbl_extend('force', {}, self)
end

local function new_transaction()
    return { index = 0, fileindex = 0, row = 0, col = 0, copy = copy_transaction }
end

local java = [[
public class CodePointTransactionalBuffer implements AutoCloseable {
	private final Iterator<Integer> input;
	private final ArrayList<Integer> lookahead;
	private final Stack<Transaction> transactions;
	private boolean closed;

	private Transaction s = new Transaction();

	private boolean hasNoTransactions() {
		return transactions.isEmpty();
	}

	public Location location() {
		return new Location(s.fileIndex, s.row, s.col);
	}

	public CodePointTransactionalBuffer(final int[] input) {
		this(IntStream.of(input).iterator());
	}

	public CodePointTransactionalBuffer(final Integer[] input) {
		this(Arrays.stream(input).iterator());
	}

	public CodePointTransactionalBuffer(final Iterable<Integer> input) {
		this(input.iterator());
	}

	public CodePointTransactionalBuffer(final Iterator<Integer> input) {
		if (input == null)
			throw new NullPointerException("input");
		this.input = input;
		lookahead = new ArrayList<>();
		transactions = new Stack<>();
	}

	private int lookaheadBufferSize() {
		return lookahead.size();
	}

	private void normalizeLookaheadBuffer() {
		if (hasNoTransactions() && s.index > 0) {
			final var available = lookaheadBufferSize() - s.index;
			for (var i = 0; i < available; i++)
				lookahead.set(i, lookahead.get(s.index + i));
			final var newsize = lookaheadBufferSize() - s.index;
			s.index = 0;
			while (lookahead.size() > newsize)
				lookahead.remove(lookahead.size() - 1);
		}
	}

	public void begin() {
		normalizeLookaheadBuffer();
		transactions.push(s);
		s = s.copy();
	}

	public void undo() {
		if (hasNoTransactions())
			throw new IllegalStateException("no transactions to roll back");
		s = transactions.pop();
		normalizeLookaheadBuffer();
	}

	public void end() {
		if (hasNoTransactions())
			throw new IllegalStateException("no transactions to roll back");
		transactions.pop();
		normalizeLookaheadBuffer();
	}

	private void updateRowCol(final int c) {
		if (c == '\n') {
			s.row++;
			s.col = 0;
		} else
			s.col++;
	}

	public String takech(final int amt) {
		assert amt > 0 : "amt must be larger than 0";
		if (peek(amt - 1) < 0)
			return null;
		final var r = new StringBuilder();
		for (int i = amt; i > 0; --i)
			r.appendCodePoint(take());
		return r.toString();
	}

	public boolean take(final int amt) {
		assert amt > 0 : "amt must be larger than 0";
		if (peek(amt - 1) < 0)
			return false;
		for (int i = 0; i < amt; ++i)
			take();
		return true;
	}

	public boolean takeUntil(final long fileIndex) {
		assert fileIndex >= s.fileIndex : "tried to consume backwards";
		while (s.fileIndex < fileIndex) {
			if (peek() < 0)
				return false;
			take();
		}
		return true;
	}

	public int take() {
		if (hasNoTransactions())
			if (s.index < lookaheadBufferSize()) {
				final var c = lookahead.get(s.index);
				if (c < 0)
					return -1;
				s.index++;
				s.fileIndex++;
				updateRowCol(c);
				return c;
			} else if (input.hasNext()) {
				s.fileIndex++;
				final var c = input.next();
				updateRowCol(c);
				return c;
			} else
				return -1;
		else if (s.index < lookaheadBufferSize()) {
			final var c = lookahead.get(s.index);
			if (c < 0)
				return -1;
			updateRowCol(c);
			s.index++;
			s.fileIndex++;
			return c;
		} else if (input.hasNext()) {
			final var c = input.next();
			updateRowCol(c);
			lookahead.add(c);
			s.index++;
			s.fileIndex++;
			return c;
		} else {
			lookahead.add(-1);
			return -1;
		}
	}

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
		if (skip < 0)
			throw new IllegalArgumentException();
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
		return peek() < 0;
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
