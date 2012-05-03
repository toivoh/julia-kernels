
# union of immutable types not to freeze/unfreeze
typealias NoFreeze Union(Number, String)

type Frozen{T,COUNT}
    item::T
    watchers::Set{WeakRef}
end

typealias FrozenArray{T,N,COUNT} Frozen{Array{T,N},COUNT}

function show{T,N,COUNT}(fr::FrozenArray{T,N,COUNT})
    print("FrozenArray{$T,$N,count=$COUNT}($(fr.item))")
end
function show{T,COUNT}(fr::Frozen{T,COUNT})
    print("Frozen{$T,fcount=$COUNT}($(fr.item))")
end

Frozen{T}(item::T) = Frozen{T,1}(item, Set{WeakRef}())
function refreeze{T,COUNT}(fr::Frozen{T,COUNT}, delta_count::Int)
    count = COUNT + delta_count
    if (count <= 0); error("can't refreeze with count <= 0"); end
    Frozen{T,count}(fr.item, fr.watchers)
end

freeze(x::NoFreeze) = x
freeze{T}(item::T) = Frozen(item)
freeze(fr::Frozen) = refreeze(fr,+1)

# callback for watchers
notify_unfreeze(::Nothing, ::Frozen) = nothing

unfreeze(x::NoFreeze) = x
function unfreeze{T}(fr::Frozen{T,1})
    for w in fr.watchers
        notify_unfreeze(w, fr)
    end
    fr.item
end
unfreeze(fr::Frozen) = refreeze(fr,-1)

# todo: check against adding/removing twice/keep ref count?
addwatcher(fr::Frozen, watcher) = (add(fr.watchers, WeakRef(watcher)); nothing)
delwatcher(fr::Frozen, watcher) = (del(fr.watchers, WeakRef(watcher)); nothing)

# usage:
# @freeze a b <body>
#
# translates to
#
# begin
#     a = freeze(a); b = freeze(b)
#     ##value = body
#     a = unfreeze(a); b = unfreeze(b)
#     ##value
# end
macro freeze(args...)
    vars = args[1:end-1]
    body = args[end]
    if !allp(v->isa(v, Symbol), vars);
        error("\n@freeze: all but last argument must be symbols")
    end
    
    pre = {:($var=freeze($var)) | var in vars}
    # todo: check that the vars haven't been changed/save them away
    post = {:($var=unfreeze($var)) | var in vars}
    value = gensym()
    body = :($value=$body)
    expr(:block, pre..., body, post..., value)
end

# todo: define common non-mutating ops to operate on fr.item
