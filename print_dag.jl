
load("transforms.jl")


# -- node type specific stuff -------------------------------------------------

pprint_nodeval(io::PrettyIO, node::NoNode) = pprint(io, "NoNode()")
pprint_nodeval(io::PrettyIO, node::LiteralNode) = pprint(io, 
                                             "LiteralNode($(node.val.value))")
pprint_nodeval(io::PrettyIO, node::SymNode) = pprint(io, 
                              "SymNode(:$(node.val.name), :$(node.val.kind))")

repargname(argname, n) = (n == 1 ? [argname] : [argname*string(k) for k=1:n])

get_signature(node::CallNode    ) = ("CallNode"    , [".op", ".arg"])
get_signature(node::RefNode     ) = ("RefNode"     , [".ref",  ".ind"])
get_signature(node::TupleNode   ) = ("TupleNode"   , [".arg"])
get_signature(node::KnotNode    ) = ("KnotNode"    , [
                           repargname(".pre",length(node.args)-1), ".value"])
get_signature(node::EllipsisNode) = ("EllipsisNode", [".arg"])
get_signature(node::AssignNode  ) = ("AssignNode"  , [".lhs", ".rhs", ".dep"])


pprint_nodeval(io::PrettyIO, node::Node) = pprint(io, "Node(", node.val, ")")


# -- pprint -------------------------------------------------------------------

function pprint(io::PrettyIO, sink::Node)
    numassigns::Int = 0
    rewrite(node::Node, args::Vector) = Node(node, args)
    function rewrite(node::ActionNode, args::Vector)
        node = Node(node, args)
        node.name = symbol("assign"*string(numassigns+=1))
        node
    end
    sink = rewrite_dag(sink, rewrite)

    firstnode = true
    for node in forward(sink)
        if has_name(node)
            pprint(io, firstnode ? "\n" : "\n\n")
            pprint_tree(io, node)
            firstnode = false
        end
    end
    if !has_name(sink)
        pprintln(io, "\n")
        pprint_tree(io, sink)       
    end
end

function pprint_tree(io::PrettyIO, node::Node)
    if has_name(node)
        pprint(io, get_name(node), "=")
    end
    if isa(node, TerminalNode)
        pprint_nodeval(io, node)
    else
        name, argnames = get_signature(node)
        numargs = length(node.args)

        dlength = numargs - length(argnames)
        argnames = [argnames[1:end-1], repargname(argnames[end], 1+dlength)]

        new_args_on_next_line::Int = 0
        on_last_arg::Bool=true
        #on_first_line::Bool=true
        #argindex::Int=1
        function newline_hook()
#             ofl, on_first_line = on_first_line, false
            nal, new_args_on_next_line = new_args_on_next_line, 0
#             split = (ofl && argindex > 1) ? ":" : (nal >= 2 ? "#" : "+")
            split  = (nal >= 2 ? "#" : "+")
            extend = (nal >= 2 ? "=" : "-")
            if nal > 0
                return split*extend*" "
            end            
            return on_last_arg ? "   " : "|  "
        end

        pprint(io, name, "(")
        let io=PrettyChild(io, newline_hook)
            lastverbose = true
            for ((arg, argname), k) in enumerate(zip(node.args, argnames))
                on_last_arg = k==numargs
                argindex = k
                verbose = !has_name(arg)
                if lastverbose || verbose
                    if on_last_arg || verbose || !has_name(node.args[k+1])
                        new_args_on_next_line = 1
                    else 
                        new_args_on_next_line = 2
                    end
                    pprint(io, '\n')
                end
                pprint(io, argname, "=")
                if verbose;  pprint_tree(io, arg);
                else         pprint(io, get_name(arg));  end
                if !on_last_arg
                    pprint(io, ", ")
                end
                lastverbose = verbose
            end
        end
        pprint(io, ")")
    end
end
