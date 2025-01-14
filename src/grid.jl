"""
Author(s): T Bltg (github.com/t-bltg)
"""
module Grid

import ..Renderables: Renderable, AbstractRenderable
import ..Measures: Measure, default_size, height, width
import ..Layout: PlaceHolder, vstack
import ..Compositors: Compositor

import Term: calc_nrows_ncols

export grid

include("_compositor.jl")

"""
    grid(
        rens::Union{AbstractVector,NamedTuple};
        placeholder::Union{Nothing,AbstractRenderable} = nothing,
        placeholder_size::Union{Nothing,Tuple} = nothing,
        aspect::Union{Nothing,Number,NTuple} = nothing,
        layout::Union{Nothing,Tuple,Expr} = nothing,
        pad::Union{Tuple,Integer} = 0,
    )

Construct a grid from an `AbstractVector`.

Lays out the renderables to create a grid with the desired aspect ratio or
layout (number of rows, number of columns, or one left free with `nothing`).
Complex layout is supported using compositor expressions.
"""
function grid(
    rens::Union{AbstractVector,NamedTuple};
    placeholder::Union{Nothing,AbstractRenderable} = nothing,
    placeholder_size::Union{Nothing,Tuple} = nothing,
    aspect::Union{Nothing,Number,NTuple} = nothing,
    layout::Union{Nothing,Tuple,Expr} = nothing,
    show_placeholder::Bool = false,
    pad::Union{Tuple,Integer} = 0,
)
    ph_style = show_placeholder ? "" : "hidden"

    rens_seq = rens isa NamedTuple ? collect(values(rens)) : rens

    if layout isa Expr
        sizes = size.(rens_seq)
        # arbitrary, if `placeholder_size` not given, take the smallest `Renderable` size for placeholders
        ph_size =
            something(placeholder_size, (minimum(first.(sizes)), minimum(last.(sizes))))

        kw = Dict{Symbol,Any}()
        n = 0
        for (i, e) in enumerate(get_elements_and_sizes(layout; placeholder_size = ph_size))
            kw[nm] = if (nm = e.args[1]) === :_
                compositor_placeholder(nm, ph_size..., ph_style)
            elseif haskey(kw, nm)
                kw[nm]  # repeated element
            elseif rens isa NamedTuple
                rens[nm]  # symbol mapping
            else
                rens[n += 1]  # stream of `Renderable`s
            end
        end
        compositor =
            Compositor(layout; placeholder_size = ph_size, check = false, pairs(kw)...)
        return Renderable(compositor)
    end

    nrows, ncols = isnothing(layout) ? calc_nrows_ncols(length(rens), aspect) : layout
    if isnothing(nrows)
        nrows, r = divrem(length(rens), ncols)
        r == 0 || (nrows += 1)
    elseif isnothing(ncols)
        ncols, r = divrem(length(rens), nrows)
        r == 0 || (ncols += 1)
    end
    fill_in = something(placeholder, PlaceHolder(first(rens); style = ph_style))
    rens_all = vcat(rens_seq, repeat([fill_in], nrows * ncols - length(rens)))
    return grid(reshape(rens_all, nrows, ncols); pad = pad)
end

"""
    grid(
        rens::Nothing = nothing;
        placeholder_size::Union{Nothing,Tuple} = nothing,
        layout::Union{Nothing,Tuple,Expr} = nothing,
        kw...
    )

Construct a grid of `PlaceHolder`s, for a given layout.
"""
function grid(
    rens::Nothing = nothing;
    placeholder_size::Union{Nothing,Tuple} = nothing,
    layout::Union{Nothing,Tuple,Expr} = nothing,
    kw...,
)
    isnothing(layout) &&
        throw(ArgumentError("`layout` must be given as `Tuple` of `Integer`s or `Expr`"))
    return grid(
        fill(PlaceHolder(something(placeholder_size, default_size())...), prod(layout));
        layout = layout,
        kw...,
    )
end

"""
    grid(rens::AbstractMatrix; pad::Union{Nothing,Integer} = 0))

Construct a grid from an `AbstractMatrix`.
"""
function grid(rens::AbstractMatrix; pad::Union{Tuple,Integer} = 0)
    hpad, vpad = if pad isa Integer
        (pad, pad)
    else
        pad
    end
    rows = collect(
        foldl((a, b) -> a * ' '^hpad * b, col[2:end]; init = first(col)) for
        col in eachrow(rens)
    )
    if vpad > 0
        vspace = vpad > 1 ? vstack(repeat([" "], vpad)...) : " "
        cat = (a, b) -> a / vspace / b
    else
        cat = (a, b) -> a / b
    end
    return foldl(cat, rows[2:end]; init = first(rows))
end

end
