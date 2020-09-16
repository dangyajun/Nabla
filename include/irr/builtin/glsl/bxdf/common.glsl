#ifndef _IRR_BSDF_COMMON_INCLUDED_
#define _IRR_BSDF_COMMON_INCLUDED_

#include <irr/builtin/glsl/math/constants.glsl>
#include <irr/builtin/glsl/math/functions.glsl>
#include <irr/builtin/glsl/limits/numeric.glsl>

#include <irr/builtin/glsl/math/functions.glsl>

// TODO: investigate covariance rendering and maybe kill this struct
// do not use this struct in SSBO or UBO, its wasteful on memory
struct irr_glsl_DirAndDifferential
{
   vec3 dir;
   // differentials at origin, I'd much prefer them to be differentials of barycentrics instead of position in the future
   mat2x3 dPosdScreen;
};

// do not use this struct in SSBO or UBO, its wasteful on memory
struct irr_glsl_IsotropicViewSurfaceInteraction
{
   irr_glsl_DirAndDifferential V; // outgoing direction, NOT NORMALIZED; V.dir can have undef value for lambertian BSDF
   vec3 N; // surface normal, NOT NORMALIZED
   float NdotV;
   float NdotV_squared;
};
struct irr_glsl_AnisotropicViewSurfaceInteraction
{
    irr_glsl_IsotropicViewSurfaceInteraction isotropic;
    vec3 T;
    vec3 B;
    float TdotV;
    float BdotV;
};

vec3 irr_glsl_getTangentSpaceV(in irr_glsl_AnisotropicViewSurfaceInteraction interaction)
{
    return vec3(interaction.TdotV,interaction.BdotV,interaction.isotropic.NdotV);
}
mat3 irr_glsl_getTangentFrame(in irr_glsl_AnisotropicViewSurfaceInteraction interaction)
{
    return mat3(interaction.T,interaction.B,interaction.isotropic.N);
}


struct irr_glsl_LightSample
{
    vec3 L;  // incoming direction, normalized
    float VdotL;

    float TdotL; 
    float BdotL;
    float NdotL;
    float NdotL2;
};

// require tangentSpaceL already be normalized and in tangent space (tangentSpaceL==vec3(TdotL,BdotL,NdotL))
irr_glsl_LightSample irr_glsl_createLightSampleTangentSpaceL(in vec3 V, in vec3 tangentSpaceL, in mat3 tangentFrame)
{
    irr_glsl_LightSample s;

    s.L = tangentFrame*tangentSpaceL; // m must be an orthonormal matrix
    s.VdotL = dot(V,s.L);

    s.TdotL = tangentSpaceL.x;
    s.BdotL = tangentSpaceL.y;
    s.NdotL = tangentSpaceL.z;
    s.NdotL2 = s.NdotL*s.NdotL;

    return s;
}
irr_glsl_LightSample irr_glsl_createLightSampleTangentSpaceL(in vec3 tangentSpaceL, in irr_glsl_AnisotropicViewSurfaceInteraction interaction)
{
    return irr_glsl_createLightSample(interaction.V.dir,tangentSpaceL,irr_glsl_getTangentFrame(interaction));
}

irr_glsl_LightSample irr_glsl_createLightSample(in vec3 L, in float VdotL, in irr_glsl_AnisotropicViewSurfaceInteraction interaction)
{
    irr_glsl_LightSample s;

    s.L = L;
    s.VdotL = VdotL;

    s.TdotL = dot(interaction.T,L);
    s.BdotL = dot(interaction.B,L);
    s.NdotL = dot(interaction.isotropic.N,L);
    s.NdotL2 = s.NdotL*s.NdotL;

    return s;
}
irr_glsl_LightSample irr_glsl_createLightSample(in vec3 L, in irr_glsl_AnisotropicViewSurfaceInteraction interaction)
{
    return irr_glsl_createLightSample(L,dot(interaction.V.dir,L);
}

//TODO move to different glsl header @Crisspl (The code is not DRY, you have something similar in material compiler!)
// chain rule on various functions (usually vertex attributes and barycentrics)
vec2 irr_glsl_applyScreenSpaceChainRule1D3(in vec3 dFdG, in mat2x3 dGdScreen)
{
   return vec2(dot(dFdG,dGdScreen[0]),dot(dFdG,dGdScreen[1]));
}
mat2 irr_glsl_applyScreenSpaceChainRule2D3(in mat3x2 dFdG, in mat2x3 dGdScreen)
{
   return dFdG*dGdScreen;
}
mat2x3 irr_glsl_applyScreenSpaceChainRule3D3(in mat3 dFdG, in mat2x3 dGdScreen)
{
   return dFdG*dGdScreen;
}
mat2x4 irr_glsl_applyScreenSpaceChainRule4D3(in mat3x4 dFdG, in mat2x3 dGdScreen)
{
   return dFdG*dGdScreen;
}

//TODO move to different glsl header @Crisspl
vec2 irr_glsl_concentricMapping(in vec2 _u)
{
    //map [0;1]^2 to [-1;1]^2
    vec2 u = 2.0*_u - 1.0;
    
    vec2 p;
    if (u==vec2(0.0))
        p = vec2(0.0);
    else
    {
        float r;
        float theta;
        if (abs(u.x)>abs(u.y)) {
            r = u.x;
            theta = 0.25*irr_glsl_PI * (u.y/u.x);
        } else {
            r = u.y;
            theta = 0.5*irr_glsl_PI - 0.25*irr_glsl_PI*(u.x/u.y);
        }
        p = r*vec2(cos(theta),sin(theta));
    }

    return p;
}

// only in the fragment shader we have access to implicit derivatives
irr_glsl_IsotropicViewSurfaceInteraction irr_glsl_calcFragmentShaderSurfaceInteraction(in vec3 _CamPos, in vec3 _SurfacePos, in vec3 _Normal)
{
   irr_glsl_IsotropicViewSurfaceInteraction interaction;
   interaction.V.dir = _CamPos-_SurfacePos;
   interaction.V.dPosdScreen[0] = dFdx(_SurfacePos);
   interaction.V.dPosdScreen[1] = dFdy(_SurfacePos);
   interaction.N = _Normal;
   float invlenV2 = inversesqrt(dot(interaction.V.dir,interaction.V.dir));
   float invlenN2 = inversesqrt(dot(interaction.N,interaction.N));
   interaction.V.dir *= invlenV2;
   interaction.N *= invlenN2;
   interaction.NdotV = dot(interaction.N,interaction.V.dir);
   interaction.NdotV_squared = interaction.NdotV*interaction.NdotV;
   return interaction;
}
irr_glsl_AnisotropicViewSurfaceInteraction irr_glsl_calcAnisotropicInteraction(in irr_glsl_IsotropicViewSurfaceInteraction isotropic, in vec3 T, in vec3 B)
{
    irr_glsl_AnisotropicViewSurfaceInteraction inter;
    inter.isotropic = isotropic;
    inter.T = T;
    inter.B = B;
    inter.TdotV = dot(inter.isotropic.V.dir,inter.T);
    inter.BdotV = dot(inter.isotropic.V.dir,inter.B);

    return inter;
}
irr_glsl_AnisotropicViewSurfaceInteraction irr_glsl_calcAnisotropicInteraction(in irr_glsl_IsotropicViewSurfaceInteraction isotropic, in vec3 T)
{
    return irr_glsl_calcAnisotropicInteraction(isotropic, T, cross(isotropic.N,T));
}
irr_glsl_AnisotropicViewSurfaceInteraction irr_glsl_calcAnisotropicInteraction(in irr_glsl_IsotropicViewSurfaceInteraction isotropic)
{
    mat2x3 TB = irr_glsl_frisvad(isotropic.N);
    return irr_glsl_calcAnisotropicInteraction(isotropic, TB[0], TB[1]);
}
/*
//TODO it doesnt compile, lots of undefined symbols
// when you know the projected positions of your triangles (TODO: should probably make a function like this that also computes barycentrics)
irr_glsl_IsotropicViewSurfaceInteraction irr_glsl_calcBarycentricSurfaceInteraction(in vec3 _CamPos, in vec3 _SurfacePos[3], in vec3 _Normal[3], in float _Barycentrics[2], in vec2 _ProjectedPos[3])
{
   irr_glsl_IsotropicViewSurfaceInteraction interaction;

   // Barycentric interpolation = b0*attr0+b1*attr1+attr2*(1-b0-b1)
   vec3 b = vec3(_Barycentrics[0],_Barycentrics[1],1.0-_Barycentrics[0]-_Barycentrics[1]);
   mat3 vertexAttrMatrix = mat3(_SurfacePos[0],_SurfacePos[1],_SurfacePos[2]);
   interaction.V.dir = _CamPos-vertexAttrMatrix*b;
   // Schied's derivation - modified
   vec2 to2 = _ProjectedPos[2]-_ProjectedPos[1];
   vec2 to1 = _ProjectedPos[0]-_ProjectedPos[1];
   float d = 1.0/determinant(mat2(to2,to1)); // TODO double check all this
   mat2x3 dBaryd = mat2x3(vec3(v[1].y-v[2].y,to2.y,to0.y)*d,-vec3(v[1].x-v[2].x,to2.x,t0.x)*d);
   //
   interaction.dPosdScreen = irr_glsl_applyScreenSpaceChainRule3D3(vertexAttrMatrix,dBaryd);

   vertexAttrMatrix = mat3(_Normal[0],_Normal[1],_Normal[2]);
   interaction.N = vertexAttrMatrix*b;

   return interaction;
}
// when you know the ray and triangle it hits
irr_glsl_IsotropicViewSurfaceInteraction  irr_glsl_calcRaySurfaceInteraction(in irr_glsl_DirAndDifferential _rayTowardsSurface, in vec3 _SurfacePos[3], in vec3 _Normal[3], in float _Barycentrics[2])
{
   irr_glsl_IsotropicViewSurfaceInteraction interaction;
   // flip ray
   interaction.V.dir = -_rayTowardsSurface.dir;
   // do some hardcore shizz to transform a differential at origin into a differential at surface
   // also in barycentrics preferably (turn world pos diff into bary diff with applyScreenSpaceChainRule3D3)
   //interaction.V.dPosdx = TODO;
   //interaction.V.dPosdy = TODO;

   vertexAttrMatrix = mat3(_Normal[0],_Normal[1],_Normal[2]);
   interaction.N = vertexAttrMatrix*b;

   return interaction;
}
*/


// do not use this struct in SSBO or UBO, its wasteful on memory
struct irr_glsl_IsotropicMicrofacetCache
{
    float VdotH;
    float LdotH;
    float NdotH;
};

// do not use this struct in SSBO or UBO, its wasteful on memory
struct irr_glsl_AnisotropicMicrofacetCache
{
    irr_glsl_IsotropicMicrofacetCache isotropic;
    float TdotH;
    float BdotH;
};

// returns if the configuration of V and L can be achieved 
bool irr_glsl_calcIsotropicMicrofacetCache(out irr_glsl_IsotropicMicrofacetCache _cache, in bool transmitted, in vec3 V, in vec3 L, in vec3 N, in float NdotL, in float orientedEta, in float rcpOrientedEta, out vec3 H)
{
    H = irr_glsl_computeMicrofacetNormal(transmitted, V, L, orientedEta);
    
    _cache.VdotH = dot(V,H);
    _cache.LdotH = dot(L,H);
    _cache.NdotH = dot(N,H);

    // not coming from the medium and exiting at the macro scale AND ( (not L outside the cone of possible directions given IoR with constraint VdotH*LdotH<0.0) OR (microfacet not facing toward the macrosurface, i.e. non heightfield profile of microsurface) ) 
    return !(transmitted && (VdotL > -min(orientedEta,rcpOrientedEta) || _cache.NdotH < 0.0));
}
bool irr_glsl_calcIsotropicMicrofacetCache(out irr_glsl_IsotropicMicrofacetCache _cache, in irr_glsl_IsotropicViewSurfaceInteraction interaction, in irr_glsl_LightSample _sample, in float eta)
{
    const float NdotV = interaction.NdotV;
    const float NdotL = _sample.NdotL;
    const bool transmitted = irr_glsl_isTransmissionPath(NdotV,NdotL);
    
    float orientedEta, rcpOrientedEta;
    const bool backside = irr_glsl_getOrientedEtas(orientedEta, rcpOrientedEta, NdotV, eta);

    return irr_glsl_calcIsotropicMicrofacetCache(_cache,transmitted,interaction.V.dir,_sample.L,interaction.N,NdotL,orientedEta,rcpOrientedEta);
}
// always valid because its specialized for the reflective case
void irr_glsl_calcIsotropicMicrofacetCache(out irr_glsl_IsotropicMicrofacetCache _cache, in float NdotV, in float NdotL, in float VdotL, out float LplusV_rcpLen)
{
    LplusV_rcpLen = inversesqrt(2.0+2.0*VdotL);

    irr_glsl_IsotropicMicrofacetCache _cache;
    _cache.VdotH = LplusV_rcpLen*VdotL+LplusV_rcpLen;
    _cache.LdotH = _cache.VdotH;
    _cache.NdotH = (NdotL+NdotV)*LplusV_rcpLen;

    return _cache;
}
irr_glsl_IsotropicMicrofacetCache irr_glsl_calcIsotropicMicrofacetCache(in irr_glsl_IsotropicViewSurfaceInteraction interaction, in irr_glsl_LightSample _sample)
{
    irr_glsl_IsotropicMicrofacetCache _cache;

    float dummy;
    return irr_glsl_calcIsotropicMicrofacetCache(_cache,interaction.NdotV,_sample.NdotL,_sample.VdotL,dummy);
}

// get extra stuff for anisotropy, here we actually require T and B to be normalized
bool irr_glsl_calcAnisotropicMicrofacetCache(out irr_glsl_AnisotropicMicrofacetCache _cache, in bool transmitted, in vec3 V, in vec3 L, in vec3 T, in vec3 B, in vec3 N, in float NdotL, in float orientedEta, in float rcpOrientedEta)
{
    vec3 H;
    const bool valid = irr_glsl_calcIsotropicMicrofacetCache(_cache.isotropic,transmitted,V,L,N,NdotL,orientedEta,rcpOrientedEta);

    _cache.TdotH = dot(T,H);
    _cache.BdotH = dot(B,H);

    return valid;
}
bool irr_glsl_calcAnisotropicMicrofacetCache(out irr_glsl_AnisotropicMicrofacetCache _cache, in irr_glsl_AnisotropicViewSurfaceInteraction interaction, in irr_glsl_LightSample _sample, in float eta)
{
    const float NdotV = interaction.NdotV;
    const float NdotL = _sample.NdotL;
    const bool transmitted = irr_glsl_isTransmissionPath(NdotV,NdotL);
    
    float orientedEta, rcpOrientedEta;
    const bool backside = irr_glsl_getOrientedEtas(orientedEta, rcpOrientedEta, NdotV, eta);

    return irr_glsl_calcAnisotropicMicrofacetCache(_cache,transmitted,interaction.V.dir,_sample.L,interaction.T,interaction.B,interaction.N,NdotL,orientedEta,rcpOrientedEta);
}
// always valid because its for the reflective case
irr_glsl_AnisotropicMicrofacetCache irr_glsl_calcAnisotropicMicrofacetCache(in irr_glsl_AnisotropicViewSurfaceInteraction interaction, in irr_glsl_LightSample _sample)
{
    irr_glsl_AnisotropicMicrofacetCache _cache;

    float LplusV_rcpLen;
    _cache.isotropic = irr_glsl_calcIsotropicMicrofacetCache(interaction.isotropic,_sample,LplusV_rcpLen);

    params.TdotH = (inter.TdotV+params.TdotL)*LplusV_rcpLen;
    params.BdotH = (inter.BdotV+params.BdotL)*LplusV_rcpLen;

   return params;
}
#endif
