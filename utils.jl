
function setdefault(d::Associative, key, value)
    if !has(d, key);  d[key] = value;  end
    return d[key]
end

function update(dest::Associative, source)
    for (key, value) in source
        dest[key] = value
    end
end

function convert{K,V}(::Type{HashTable{K,V}}, d::Associative)
    c = HashTable{K,V}(length(d))
    update(c, d)
    c
end

# copies entries but does not deep copy the keys/values
function copydict{K,V}(d::HashTable{K,V})
    c = HashTable{K,V}(length(d))
    update(c, d)
    c
end


quote_sym(sym::Symbol) = expr(:quote, sym)
 
macro dict(args...)   
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

