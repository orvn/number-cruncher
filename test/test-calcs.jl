# Test values

using Test

include("../chudnovsky-pi.jl")
include("../euler-e.jl")
include("../heron-root.jl")
include("../newton-root.jl")
include("../apery-zeta.jl")

# first ~50 places
const PI_52    = "3.14159265358979323846264338327950288419716939937510"
const E_52     = "2.71828182845904523536028747135266249775724709369995"
const SQRT2_52 = "1.41421356237309504880168872420969807856967187537694"
const ZETA3_52 = "1.20205690315959428539973816151144999076498629234049"

leading52(x::BigFloat) = first(string(x), 52)

@testset "number-cruncher" begin

    @testset "known constants — first 50 digits" begin
        @test leading52(π_chud(digits = 100))      == PI_52
        @test leading52(e_taylor(digits = 100))    == E_52
        @test leading52(sqrt2_heron(digits = 100)) == SQRT2_52
        @test leading52(zeta3_apery(digits = 100)) == ZETA3_52
    end

    @testset "newton-root — √n · √n ≈ n" begin
        for n in [2, 3, 5, 7, 11, 42]
            x = sqrt_newton(n, digits = 100)
            @test abs(x^2 - BigFloat(n)) < BigFloat(10)^-90
        end
    end

    @testset "newton-root — perfect squares converge exactly" begin
        @test sqrt_newton(9,   digits = 50) == BigFloat(3)
        @test sqrt_newton(16,  digits = 50) == BigFloat(4)
        @test sqrt_newton(100, digits = 50) == BigFloat(10)
    end

    @testset "humanize_digits boundaries" begin
        @test humanize_digits(0)                 == "0"
        @test humanize_digits(999)               == "999"
        @test humanize_digits(1_000)             == "1.0K"
        @test humanize_digits(1_500_000)         == "1.5M"
        @test humanize_digits(1_500_000_000)     == "1.5B"
        @test humanize_digits(1_500_000_000_000) == "1.5T"
    end

    @testset "format_value — floor threshold" begin
        # below floor
        setprecision(100)  # ~30 decimal places
        plain, _ = format_value(BigFloat(1) / BigFloat(3), 120)
        @test !occursin("…", plain)

        # above floor
        setprecision(4000)  # ~1200 decimal places
        plain, _ = format_value(BigFloat(1) / BigFloat(3), 120)
        @test occursin("…", plain)
        @test occursin("digits}", plain)
    end

end
