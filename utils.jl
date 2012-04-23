
function setdefault(d::Associative, key, value)
# set d[key]=value if not present; return d[key]
    if !has(d, key);  d[key] = value;  end
    return d[key]
end

function update(dest::Associative, source)
# add entries to dest, overwriting existing ones
    for (key, value) in source
        dest[key] = value
    end
end

function makedict{K,V}(::Type{K}, ::Type{V}, sources...)
# make a HashTable{K,V} out of an Associative/(key,value) iterable
    d = HashTable{K,V}()
    for source in sources
        update(d, source)
    end
    d
end

# copy HashTable entries, but don't deep copy the keys/values
copydict{K,V}(d::HashTable{K,V}) = makedict(K,V,d)

#convert{K,V}(::Type{HashTable{K,V}}, d::Associative) = copydict{K,V}(d)


quote_sym(sym::Symbol) = expr(:quote, sym)
 
macro dict(args...)   
# Create a HashTable{Symbol}
# Usage:
#     d = @dict x=1 s="hello"
# is equivalent to 
#     d = {:x => 1, :s => "hello"}
# except that @dict throws an error on duplicate keys

    names = Set{Symbol}()
    toentry(arg) = error("@dict: malformed argument $arg")
    function toentry(ex::Expr)
        if ex.head != :(=); error("@dict: not an assignment: $ex"); end

        # check name duplicates
        name = ex.args[1]
        if has(names, name); error("@dict: duplicate definition of $name"); end
        add(names, name)

        expr(:(=>), quote_sym(name), ex.args[2])
    end
    expr(:cell1d, { toentry(arg) | arg in args } )
end

