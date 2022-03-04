return function()
    local parity, head, tail, capacity, version, buf = false, 0, 0, 1, 0, {}
    local ret = {}
    local function size()
        if parity then
            return capacity - (tail - head)
        else
            return head - tail
        end
    end
    ret.size = size()

    local function iterator()
        local h = head
        local p = parity
        local v = version

        return function()
            if v ~= version then
                error 'collection modified while being iterated'
            end
            if h == tail and not p then
                return nil
            end
            h = h + 1
            local r = buf[h]
            if h == capacity then
                p = not p
                h = 0
            end
            return r
        end
    end

    local function grow()
        local newbuf = {}
        for x in iterator() do
            table.insert(newbuf, x)
        end
        head = size()
        buf = newbuf
        capacity = capacity * 2
        parity = false
        tail = 0
    end

    function ret.push_back(item)
        if parity and head == tail then
            grow()
        end
        head = head + 1
        buf[head] = item
        if head == capacity then
            parity, head = not parity, 0
        end
        version = version + 1
    end

    function ret.push_front(item)
        if parity and head == tail then
            grow()
        end
        if tail == 0 then
            tail, parity = capacity, not parity
        end
        buf[tail] = item
        tail = tail - 1
        version = version + 1
    end

    function ret.pop_front()
        if parity or head ~= tail then
            tail = tail + 1
            local r = buf[tail]
            buf[tail] = nil
            if tail == capacity then
                parity, tail = not parity, 0
            end
            version = version + 1
            return r
        end
    end

    function ret.pop_back()
        if parity or head ~= tail then
            if head == 0 then
                parity, head = not parity, capacity
            end
            local r = buf[head]
            head, version = head - 1, version + 1
            return r
        end
    end
    return ret
end
