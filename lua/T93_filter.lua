return {
    func = function(input, env)
        for cand in input:iter() do
            if cand.type == 'punct' then
                cand.comment = ''
            end
            yield(cand)
        end
    end
}
