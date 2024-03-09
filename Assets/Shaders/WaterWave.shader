Shader "WaterWave"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _RingWidth("Ring Width", float) = 0.1
        _RingRange("Ring Range", float) = 0.2
        _RingSmoothness("Ring Smoothness", float) = 0.1
        _BumpPower("Bump Power", float) = 1.0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            float _RingWidth;
            float _RingRange;
            float _RingSmoothness;
            float _BumpPower;

            sampler2D _MainTex;
            float4 _MainTex_ST;

            float doubleSmoothstep(float2 uv)
            {
                float dis = distance(uv, 0.5);
                float halfWidth = _RingWidth * 0.5;
                float range = _RingRange;
                float smoothness = _RingSmoothness;
                float threshold1 = range - halfWidth;
                float threshold2 = range + halfWidth;

                float value = smoothstep(threshold1, threshold1 + smoothness, dis);
                float value2 = smoothstep(threshold2, threshold2 + smoothness, dis);

                return value - value2;
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float normalCenter = doubleSmoothstep(i.uv);
                // ²¨ÎÆ·¨Ïß
                float color0 = doubleSmoothstep(i.uv + half4(-1, 0, 0, 0) * 0.004);
                float color1 = doubleSmoothstep(i.uv + half4(1, 0, 0, 0) * 0.004);
                float color2 = doubleSmoothstep(i.uv + half4(0, -1, 0, 0) * 0.004);
                float color3 = doubleSmoothstep(i.uv + half4(0, 1, 0, 0) * 0.004);

                float2 ddxy = float2(color0 - color1, color2 - color3);
                float3 normal = float3((ddxy * _BumpPower), 1.0);
                normal = normalize(normal);
                float4 finalColor = float4((normal * 0.5 + 0.5) * normalCenter, normalCenter);
                return finalColor;
            }
            ENDCG
        }
    }
}
