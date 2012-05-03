
#load("utils/utils.jl")

const doublecolon = @eval (:(x::Int)).head

type Unfinished; end
unfinished = Unfinished()

type DictEntry{K,V}
    dict::Dict{K,V}
    key::K
end
DictEntry{K,V}(dict::Dict{K,V}, key) = DictEntry{K,V}(dict, key)

present(entry::DictEntry)   = has(entry.dict, entry.key)
ref(entry::DictEntry)       = entry.dict[entry.key]
assign(entry::DictEntry, x) = (entry.dict[entry.key] = x)

typealias Cache Dict{Function, Dict}

function cacheentry(f::Function, c::Cache, args...)
    DictEntry((@setdefault c[f] Dict()), args)
end


function cached_call(call)
    fullcall = call
    if is_expr(call, doublecolon)
        @expect length(call.args) == 2
        returntype = call.args[2]
        call = call.args[1]
    else
        returntype = Any
    end
    @expect is_expr(call, :call)
    quote
        let entry = cacheentry($call.args...) # args[1] = the function
            local value
            if present(entry)
                value = entry[]
                if is(value, unfinished)
                    error("Reentered evalutation of ( @cached ", 
                          ($string(fullcall)), " )\nwith arguments = ", 
                          ($expr(:tuple, call.args[2:end])))
                end
                value::($returntype)
            else
                entry[] = unfinished
                entry[] = value = ($fullcall)
                value
            end
        end
    end
end

macro cached(call)
    cached_call(call)
end
