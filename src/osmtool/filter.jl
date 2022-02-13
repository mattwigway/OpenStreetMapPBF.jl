# create a filter function from Julia code parsed from the command line
function generate_filter(filter_string)
    expr = Meta.parse(filter_string)
    expr = postwalk(expr) do x
        # convert bare tags to references into tags dict, or nothing if obj does not have tag
        if x isa Symbol && !hasproperty(Base, x)
            return :(get(feature.tags, $(string(x)), nothing))
        else
            return x
        end
    end

    return @RuntimeGeneratedFunction :(feature -> $expr)
end