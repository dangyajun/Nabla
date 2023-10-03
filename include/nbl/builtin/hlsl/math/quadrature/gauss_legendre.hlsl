// Copyright (C) 2018-2023 - DevSH Graphics Programming Sp. z O.O.
// This file is part of the "Nabla Engine".
// For conditions of distribution and use, see copyright notice in nabla.h
#ifndef _NBL_BUILTIN_HLSL_MATH_QUADRATURE_GAUSS_LEGENDRE_INCLUDED_
#define _NBL_BUILTIN_HLSL_MATH_QUADRATURE_GAUSS_LEGENDRE_INCLUDED_

#include <nbl/builtin/hlsl/cpp_compat.hlsl>


namespace nbl
{
namespace hlsl
{
namespace math
{
namespace quadrature
{
        template<int Order, typename float_t>
        struct GaussLegendreValues 
        {};

        template<int Order, typename float_t, class IntegrandFunc>
        struct GaussLegendreIntegration
        {
            static float_t calculateIntegral(NBL_CONST_REF_ARG(IntegrandFunc) func, float_t start, float_t end)
            {
                float_t integral = 0.0;
                for (uint32_t i = 0u; i < Order; ++i)
                {
                    float_t xi = GaussLegendreValues<Order, float_t>::xi(i)* ((end - start) / 2.0) + ((end + start) / 2.0);
                    integral += GaussLegendreValues<Order, float_t>::wi(i) * func(xi);
                }
                return ((end - start) / 2.0) * integral;
            }
        };

        namespace impl
        {
        NBL_CONSTEXPR double xi_2[2] = {
            -0.5773502691896257,
            0.5773502691896257 };

        NBL_CONSTEXPR double xi_3[3] = {
             0,
            -0.7745966692414833,
            0.7745966692414833 };

        NBL_CONSTEXPR double xi_4[4] = {
            -0.3399810435848562,
            0.3399810435848562,
            -0.8611363115940525,
            0.8611363115940525 };

        NBL_CONSTEXPR double xi_5[5] = {
            0,
            -0.5384693101056830,
            0.5384693101056830,
            -0.9061798459386639,
            0.9061798459386639 };

        NBL_CONSTEXPR double xi_6[6] = {
            0.6612093864662645,
            -0.6612093864662645,
            -0.2386191860831969,
            0.2386191860831969,
            -0.9324695142031520,
            0.9324695142031520 };

        NBL_CONSTEXPR double xi_7[7] = {
            0,
            0.4058451513773971,
            -0.4058451513773971,
            -0.7415311855993944,
            0.7415311855993944,
            -0.9491079123427585,
            0.9491079123427585 };

        NBL_CONSTEXPR double xi_8[8] = {
            -0.1834346424956498,
            0.1834346424956498,
            -0.5255324099163289,
            0.5255324099163289,
            -0.7966664774136267,
            0.7966664774136267,
            -0.9602898564975362,
            0.9602898564975362 };

        NBL_CONSTEXPR double xi_9[9] = {
            0,
            -0.8360311073266357,
            0.8360311073266357,
            -0.9681602395076260,
            0.9681602395076260,
            -0.3242534234038089,
            0.3242534234038089,
            -0.6133714327005903,
            0.6133714327005903 };

        NBL_CONSTEXPR double xi_10[10] = {
            -0.1488743389816312,
            0.1488743389816312,
            -0.4333953941292471,
            0.4333953941292471,
            -0.6794095682990244,
            0.6794095682990244,
            -0.8650633666889845,
            0.8650633666889845,
            -0.9739065285171717,
            0.9739065285171717 };

        NBL_CONSTEXPR double xi_11[11] = {
            0,
            -0.2695431559523449,
            0.2695431559523449,
            -0.5190961292068118,
            0.5190961292068118,
            -0.7301520055740493,
            0.7301520055740493,
            -0.8870625997680952,
            0.8870625997680952,
            -0.9782286581460569,
            0.9782286581460569 };

        NBL_CONSTEXPR double xi_12[12] = {
            -0.1252334085114689,
            0.1252334085114689,
            -0.3678314989981801,
            0.3678314989981801,
            -0.5873179542866174,
            0.5873179542866174,
            -0.7699026741943046,
            0.7699026741943046,
            -0.9041172563704748,
            0.9041172563704748,
            -0.9815606342467192,
            0.9815606342467192 };

        NBL_CONSTEXPR double xi_13[13] = {
            0,
            -0.2304583159551347,
            0.2304583159551347,
            -0.4484927510364468,
            0.4484927510364468,
            -0.6423493394403402,
            0.6423493394403402,
            -0.8015780907333099,
            0.8015780907333099,
            -0.9175983992229779,
            0.9175983992229779,
            -0.9841830547185881,
            0.9841830547185881 };

        NBL_CONSTEXPR double xi_14[14] = {
            -0.1080549487073436,
            0.1080549487073436,
            -0.3191123689278897,
            0.3191123689278897,
            -0.5152486363581540,
            0.5152486363581540,
            -0.6872929048116854,
            0.6872929048116854,
            -0.8272013150697649,
            0.8272013150697649,
            -0.9284348836635735,
            0.9284348836635735,
            -0.9862838086968123,
            0.9862838086968123 };

        NBL_CONSTEXPR double xi_15[15] = {
            0,
            -0.2011940939974345,
            0.2011940939974345,
            -0.3941513470775633,
            0.3941513470775633,
            -0.5709721726085388,
            0.5709721726085388,
            -0.7244177313601700,
            0.7244177313601700,
            -0.8482065834104272,
            0.8482065834104272,
            -0.9372733924007059,
            0.9372733924007059,
            -0.9879925180204854,
            0.9879925180204854 };

        NBL_CONSTEXPR double wi_2[2] = {
            1.0000000000000000,
            1.0000000000000000 };

        NBL_CONSTEXPR double wi_3[3] = {
            0.8888888888888888,
            0.5555555555555555,
            0.5555555555555555 };

        NBL_CONSTEXPR double wi_4[4] = {
            0.6521451548625461,
            0.6521451548625461,
            0.3478548451374538,
            0.3478548451374538 };

        NBL_CONSTEXPR double wi_5[5] = {
            0.5688888888888888,
            0.4786286704993664,
            0.4786286704993664,
            0.2369268850561890,
            0.2369268850561890 };

        NBL_CONSTEXPR double wi_6[6] = {
            0.3607615730481386,
            0.3607615730481386,
            0.4679139345726910,
            0.4679139345726910,
            0.1713244923791703,
            0.1713244923791703 };

        NBL_CONSTEXPR double wi_7[7] = {
            0.4179591836734693,
            0.3818300505051189,
            0.3818300505051189,
            0.2797053914892766,
            0.2797053914892766,
            0.1294849661688696,
            0.1294849661688696 };

        NBL_CONSTEXPR double wi_8[8] = {
            0.3626837833783619,
            0.3626837833783619,
            0.3137066458778872,
            0.3137066458778872,
            0.2223810344533744,
            0.2223810344533744,
            0.1012285362903762,
            0.1012285362903762 };

        NBL_CONSTEXPR double wi_9[9] = {
            0.3302393550012597,
            0.1806481606948574,
            0.1806481606948574,
            0.0812743883615744,
            0.0812743883615744,
            0.3123470770400028,
            0.3123470770400028,
            0.2606106964029354,
            0.2606106964029354 };

        NBL_CONSTEXPR double wi_10[10] = {
            0.2955242247147528,
            0.2955242247147528,
            0.2692667193099963,
            0.2692667193099963,
            0.2190863625159820,
            0.2190863625159820,
            0.1494513491505805,
            0.1494513491505805,
            0.0666713443086881,
            0.0666713443086881 };

        NBL_CONSTEXPR double wi_11[11] = {
            0.2729250867779006,
            0.2628045445102466,
            0.2628045445102466,
            0.2331937645919904,
            0.2331937645919904,
            0.1862902109277342,
            0.1862902109277342,
            0.1255803694649046,
            0.1255803694649046,
            0.0556685671161736,
            0.0556685671161736 };

        NBL_CONSTEXPR double wi_12[12] = {
            0.2491470458134027,
            0.2491470458134027,
            0.2334925365383548,
            0.2334925365383548,
            0.2031674267230659,
            0.2031674267230659,
            0.1600783285433462,
            0.1600783285433462,
            0.1069393259953184,
            0.1069393259953184,
            0.0471753363865118,
            0.0471753363865118 };

        NBL_CONSTEXPR double wi_13[13] = {
            0.2325515532308739,
            0.2262831802628972,
            0.2262831802628972,
            0.2078160475368885,
            0.2078160475368885,
            0.1781459807619457,
            0.1781459807619457,
            0.1388735102197872,
            0.1388735102197872,
            0.0921214998377284,
            0.0921214998377284,
            0.0404840047653158,
            0.0404840047653158 };

        NBL_CONSTEXPR double wi_14[14] = {
            0.2152638534631577,
            0.2152638534631577,
            0.2051984637212956,
            0.2051984637212956,
            0.1855383974779378,
            0.1855383974779378,
            0.1572031671581935,
            0.1572031671581935,
            0.1215185706879031,
            0.1215185706879031,
            0.0801580871597602,
            0.0801580871597602,
            0.0351194603317518,
            0.0351194603317518 };

        NBL_CONSTEXPR double wi_15[15] = {
            0.2025782419255612,
            0.1984314853271115,
            0.1984314853271115,
            0.1861610000155622,
            0.1861610000155622,
            0.1662692058169939,
            0.1662692058169939,
            0.1395706779261543,
            0.1395706779261543,
            0.1071592204671719,
            0.1071592204671719,
            0.0703660474881081,
            0.0703660474881081,
            0.0307532419961172,
            0.0307532419961172 };

        }

        template <typename float_t>
        struct GaussLegendreValues<2, float_t> 
        {
            static float_t xi(uint32_t idx) { return impl::xi_2[idx]; }
            static float_t wi(uint32_t idx) { return impl::wi_2[idx]; }
        };
        template <typename float_t>
        struct GaussLegendreValues<3, float_t> 
        {
            static float_t xi(uint32_t idx) { return impl::xi_3[idx]; }
            static float_t wi(uint32_t idx) { return impl::wi_3[idx]; }
        };
        template <typename float_t>
        struct GaussLegendreValues<4, float_t> 
        {
            static float_t xi(uint32_t idx) { return impl::xi_4[idx]; }
            static float_t wi(uint32_t idx) { return impl::wi_4[idx]; }
        };
        template <typename float_t>
        struct GaussLegendreValues<5, float_t> 
        {
            static float_t xi(uint32_t idx) { return impl::xi_5[idx]; }
            static float_t wi(uint32_t idx) { return impl::wi_5[idx]; }
        };
        template <typename float_t>
        struct GaussLegendreValues<6, float_t> 
        {
            static float_t xi(uint32_t idx) { return impl::xi_6[idx]; }
            static float_t wi(uint32_t idx) { return impl::wi_6[idx]; }
        };
        template <typename float_t>
        struct GaussLegendreValues<7, float_t> 
        {
            static float_t xi(uint32_t idx) { return impl::xi_7[idx]; }
            static float_t wi(uint32_t idx) { return impl::wi_7[idx]; }
        };
        template <typename float_t>
        struct GaussLegendreValues<8, float_t> 
        {
            static float_t xi(uint32_t idx) { return impl::xi_8[idx]; }
            static float_t wi(uint32_t idx) { return impl::wi_8[idx]; }
        };
        template <typename float_t>
        struct GaussLegendreValues<9, float_t> 
        {
            static float_t xi(uint32_t idx) { return impl::xi_9[idx]; }
            static float_t wi(uint32_t idx) { return impl::wi_9[idx]; }
        };
        template <typename float_t>
        struct GaussLegendreValues<10, float_t> 
        {
            static float_t xi(uint32_t idx) { return impl::xi_10[idx]; }
            static float_t wi(uint32_t idx) { return impl::wi_10[idx]; }
        };
        template <typename float_t>
        struct GaussLegendreValues<11, float_t> 
        {
            static float_t xi(uint32_t idx) { return impl::xi_11[idx]; }
            static float_t wi(uint32_t idx) { return impl::wi_11[idx]; }
        };
        template <typename float_t>
        struct GaussLegendreValues<12, float_t> 
        {
            static float_t xi(uint32_t idx) { return impl::xi_12[idx]; }
            static float_t wi(uint32_t idx) { return impl::wi_12[idx]; }
        };
        template <typename float_t>
        struct GaussLegendreValues<13, float_t> 
        {
            static float_t xi(uint32_t idx) { return impl::xi_13[idx]; }
            static float_t wi(uint32_t idx) { return impl::wi_13[idx]; }
        };
        template <typename float_t>
        struct GaussLegendreValues<14, float_t> 
        {
            static float_t xi(uint32_t idx) { return impl::xi_14[idx]; }
            static float_t wi(uint32_t idx) { return impl::wi_14[idx]; }
        };
        template <typename float_t>
        struct GaussLegendreValues<15, float_t> 
        {
            static float_t xi(uint32_t idx) { return impl::xi_15[idx]; }
            static float_t wi(uint32_t idx) { return impl::wi_15[idx]; }
        };
} // quadrature
} // math
} // hlsl
} // nbl

#endif
