Shader "NormalMap"
{
    Properties
    {
        [HideInInspector]_MainTex ("Texture", 2D) = "white" {}
        _ShallowColor("Shallow Color", Color) = (1,1,1,1)
        _DeepColor("Deep Color", Color) = (1,1,1,1)
        _DepthParam("Depth Range", Range(0.01, 1.0)) = 1.0
        _Gloss("Gloss", float) = 1.0
        _SpecColor("SpecColor", Color) = (1,1,1,1)
        _NormalMap("Normal Map", 2D) = "white" {}
        _WaveSpeed("Wave Speed", Vector) = (1,1,0,0)
        _Distortion("Distortion", float) = 1.0

        _FoamTex("Foam Texture", 2D) = "black" {}
        //_NoiseCutoff("Noise Cutoff", Range(0.0,1.0)) = 0.5
        _FoamRange("Foam Range", Range(0.01, 1.5)) = 0.5
        //_FoamSpeed("Foam Speed", float) = 1.0
        _FoamStrength("Foam Strength", float) = 1.0
        _FoamDistortion("Foam Distortion", Range(0, 0.05)) = 0.0

        _ReflectionTex("Reflection Texture", 2D) = "white"{}

        _AlphaRange("Transparent Range", Range(0, 3.0)) = 1.0
    }
    SubShader
    {
        Tags { "RenderType" = "Transparent" "RenderPipeline" = "UniversalPipeline" "Queue" = "Transparent" }

        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct appdata
            {
                float4 positionOS    : POSITION;
                float3 normalOS      : NORMAL;
                float4 tangentOS     : TANGENT;
                float2 uv            : TEXCOORD0;
            };

            struct v2f
            {
                float4 positionCS : SV_POSITION;
                float4 uv        : TEXCOORD0;
                float3 viewDirWS : TEXCOORD1;

                float3 normal    : TEXCOORD2;
                float3 tangent   : TEXCOORD3;
                float3 bitangent : TEXCOORD4;

                float4 screenPos : TEXCOORD5;
            };

            half3 _ShallowColor;
            half3 _DeepColor;
            float _DepthParam;
            half _Gloss;
            half4 _SpecColor;
            float4 _WaveSpeed;
            float _Distortion;
            float _FoamRange;
            //float _FoamSpeed;
            float _FoamStrength;
            float _FoamDistortion;
            //float _NoiseCutoff;
            float _AlphaRange;

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            float4 _MainTex_ST;

            TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);
            float4 _NormalMap_ST;

            TEXTURE2D(_CameraOpaqueTexture);
            SAMPLER(sampler_CameraOpaqueTexture);

            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);

            TEXTURE2D(_FoamTex);
            SAMPLER(sampler_FoamTex);
            float4 _FoamTex_ST;

            TEXTURE2D(_ReflectionTex);
            SAMPLER(sampler_ReflectionTex);

            v2f vert(appdata v)
            {
                v2f o;
                o.positionCS = TransformObjectToHClip(v.positionOS.xyz);
                o.uv.xy = TRANSFORM_TEX(v.uv, _FoamTex);
                o.uv.zw = TRANSFORM_TEX(v.uv, _NormalMap) * 3;

                o.normal = normalize(mul(v.normalOS, (float3x3)unity_ObjectToWorld));
                o.tangent = normalize(mul((float3x3)unity_WorldToObject, v.tangentOS.xyz));
                o.bitangent = cross(o.normal, o.tangent) * v.tangentOS.w;

                half3 positionWS = TransformObjectToWorld(v.positionOS.xyz);
                o.viewDirWS = _WorldSpaceCameraPos - positionWS;

                o.screenPos = ComputeScreenPos(o.positionCS);

                return o;
            }

            half4 frag(v2f i) : SV_Target
            {
                //法线
                float2 speed = _Time.y * float2(_WaveSpeed.x, _WaveSpeed.y) * 0.1;
                half4 normalTex_1 = SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, i.uv.zw + speed);
                half3 normalTS_1 = UnpackNormal(normalTex_1);
                half4 normalTex_2 = SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, i.uv.zw - speed + float2(0.0, 0.2));//防止两张图重合
                half3 normalTS_2 = UnpackNormal(normalTex_2);
                half3 normalTS = normalize(normalTS_1 + normalTS_2);
                float3x3 tangentToWorldMatrix = float3x3(i.tangent.xyz, i.bitangent.xyz, i.normal.xyz);
                half3 normalWS = normalize(mul(normalTS, tangentToWorldMatrix));

                half3 lightDir = saturate(_MainLightPosition.xyz);

                /*
                //漫反射
                half3 diffuse = saturate(dot(lightDir, normalWS)) *  _ShallowColor;
                */

                //高光
                i.viewDirWS = normalize(i.viewDirWS);
                half3 halfDir = normalize(i.viewDirWS + lightDir);
                half3 specular = pow(max(0, dot(normalWS, halfDir)), _Gloss) * _SpecColor.rgb;

                //交互遮罩
                half interactionDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, i.screenPos.xy/i.screenPos.w);
                interactionDepth = LinearEyeDepth(interactionDepth, _ZBufferParams);
                half interactionDepthDiff = 1 - (interactionDepth - i.screenPos.w);
                half interactionMask = interactionDepthDiff * _FoamRange;

                //交互纹理
                /*i.uv.y -= _Time.y * _FoamSpeed * 0.01;
                half4 foamTexCol = SAMPLE_TEXTURE2D(_FoamTex, sampler_FoamTex, i.uv.xy * 5);
                half4 foamColor = (foamTexCol.r + 1.2) * interactionMask;
                foamColor = step(0.16, foamColor);*/

                //2
                half4 foamTexCol = SAMPLE_TEXTURE2D(_FoamTex, sampler_FoamTex, i.uv.xy + normalTS.xy * _Distortion * _FoamDistortion);
                half3 foamColor = saturate(foamTexCol * interactionMask * _FoamStrength).rgb;

                //3
                /*float foamDelta = sin(_Time.y) * 0.5 + 0.5;
                float s1 = smoothstep(foamDelta, foamDelta + 0.1, interactionMask);
                float s2 = smoothstep(foamDelta + 0.2, foamDelta + 0.3, interactionMask);
                float foamMask = s1 - s2;
                half4 foamColor = SAMPLE_TEXTURE2D(_FoamTex, sampler_FoamTex, i.uv.xy*5) * foamMask;
                foamColor = saturate(foamColor)*0.8;*/

                //计算偏移量和扰动遮罩
                float2 offset = normalTS.xy * _Distortion;//偏移量
                float2 screenPos_offset = (i.screenPos.xy + offset * i.screenPos.z) / i.screenPos.w;//偏移量随深度增加
                //扰动遮罩，旁边的点的深度值如果比自己的小，说明旁边的点是前景，则采样背景时不偏移
                half depthTex_offset = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, screenPos_offset);
                half depth_offset = LinearEyeDepth(depthTex_offset, _ZBufferParams);
                half depthDifference_offset = depth_offset - i.screenPos.w;
                if(depthDifference_offset < 0)
                {
                    screenPos_offset = i.screenPos.xy / i.screenPos.w;
                }

                //折射
                half3 refractTex = SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, screenPos_offset).rgb;
                //反射
                half3 reflectTex = SAMPLE_TEXTURE2D(_ReflectionTex, sampler_ReflectionTex, screenPos_offset).rgb;
                //菲涅尔
                half fresnel = pow(1 - saturate(dot(i.viewDirWS, normalWS)), 4);
                half3 frenelColor = reflectTex * fresnel + refractTex * (1 - fresnel);

                //扰动后的深度差值
                half depthTex = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, screenPos_offset);
                half depth = LinearEyeDepth(depthTex, _ZBufferParams);
                half depthDifference = saturate(depth - i.screenPos.w);
                //深浅区颜色
                half3 baseColor = lerp(_ShallowColor, _DeepColor, depthDifference / _DepthParam);

                half alpha = saturate(lerp(1, 0, interactionDepthDiff * _AlphaRange));

                half3 color = saturate(baseColor * frenelColor + foamColor + specular);
                return half4(color, alpha);
            }
            ENDHLSL
        }
    }
}