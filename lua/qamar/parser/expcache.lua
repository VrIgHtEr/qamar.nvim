local M = {}

local heap = { count = 0 }
local map = {}

function heap.push(tokenid, item)
    heap.count = heap.count + 1
    local pos = heap.count
    heap[pos] = { id = tokenid, value = item }
    while pos > 1 do
        local parent = math.floor(pos / 2)
        if heap[parent].id <= tokenid then
            return
        end
        heap[parent], heap[pos], pos = heap[pos], heap[parent], parent
    end
end

function heap.pop()
    if heap.count > 0 then
        local ret = heap[1]
        if heap.count == 1 then
            heap.count = 0
        else
            heap[1], heap.count = heap[heap.count], heap.count - 1
            local pos, max = 1, math.floor(heap.count / 2)
            while pos <= max do
                local child = pos * 2
                if child < heap.count and heap[child + 1].id < heap[child].id then
                    child = child + 1
                end
                if heap[child].id >= heap[pos].id then
                    break
                end
                heap[child], heap[pos], pos = heap[pos], heap[child], child
            end
        end
        return ret
    end
end

function heap.peek()
    if heap.count > 0 then
        return heap[1]
    end
end

function M.discard(tokenid)
    while heap.count > 0 do
        local item = heap.peek()
        if item.id >= tokenid then
            break
        end
        heap.pop()
        map[item.id] = nil
    end
end

function M.add(tokenid, nextid, precedence, item)
    local cache = map[tokenid]
    if not cache then
        cache = {}
        map[tokenid] = cache
        heap.push(tokenid, cache)
    end
    cache[precedence] = { nextid = nextid, value = item }
    --print(vim.inspect(heap))
end

function M.get(tokenid, precedence)
    local cache = map[tokenid]
    if cache then
        return cache[precedence]
    end
end

return M
