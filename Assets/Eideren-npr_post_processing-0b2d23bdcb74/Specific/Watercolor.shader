
// "Watercolor" by florian "flockaroo" berger @ https://www.shadertoy.com/view/ltyGRV
// Use this code in accordance to the license holder's license !



Shader "ImageFilter/Watercolor"
{
	Properties
	{
		TexChannel1 ("Texture1", 2D) = "white" {}
		TexChannel2 ("Texture2", 2D) = "white" {}
		
	}
	SubShader
	{
		Tags
		{
			"RenderType"="Overlay"
			"Queue"="Overlay"
			
		}
		ZWrite Off
		GrabPass{ }
		
		
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"
			
			#define TexChannel0 _GrabTexture
			#define TexChannel0_TexelSize _GrabTexture_TexelSize
			
			
			struct vIn
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};
			
			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
				float4 screenPos : TEXCOORD5;
				
			};
			
			sampler2D TexChannel1;
			float4 TexChannel1_TexelSize;
			sampler2D TexChannel2;
			float4 TexChannel2_TexelSize;
			sampler2D _GrabTexture;
			float4 _GrabTexture_TexelSize;
			
			
			v2f vert (vIn v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				o.screenPos = o.vertex;
				
				return o;
			}
			
			// created by florian berger (flockaroo) - 2016
			// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.
			
			// trying to resemble watercolors
			
			#define Res  _ScreenParams.xy
			#define Res0 TexChannel0_TexelSize.zwxy.xy
			#define Res1 TexChannel1_TexelSize.zwxy.xy
			
			#define PI 3.14159265358979
			
			float4 getCol(float2 pos)
			{
				float2 uv=pos/Res0;
				float4 c1 = tex2D(TexChannel0,uv);
				float4 c2 = (.4); // gray on greenscreen
				float d = clamp(dot(c1.xyz,float3(-0.5,1.0,-0.5)),0.0,1.0);
				return lerp(c1,c2,1.8*d);
			}
			
			float4 getCol2(float2 pos)
			{
				float2 uv=pos/Res0;
				float4 c1 = tex2D(TexChannel0,uv);
				float4 c2 = (1.5); // bright white on greenscreen
				float d = clamp(dot(c1.xyz,float3(-0.5,1.0,-0.5)),0.0,1.0);
				return lerp(c1,c2,1.8*d);
			}
			
			float2 getGrad(float2 pos,float delta)
			{
				float2 d=float2(delta,0);
				return float2(
				dot((getCol(pos+d.xy)-getCol(pos-d.xy)).xyz,(.333)),
				dot((getCol(pos+d.yx)-getCol(pos-d.yx)).xyz,(.333))
				)/delta;
			}
			
			float2 getGrad2(float2 pos,float delta)
			{
				float2 d=float2(delta,0);
				return float2(
				dot((getCol2(pos+d.xy)-getCol2(pos-d.xy)).xyz,(.333)),
				dot((getCol2(pos+d.yx)-getCol2(pos-d.yx)).xyz,(.333))
				)/delta;
			}
			
			float4 getRand(float2 pos)
			{
				float2 uv=pos/Res1;
				return tex2D(TexChannel1,uv);
			}
			
			float htPattern(float2 pos)
			{
				float p;
				float r=getRand(pos*.4/.7*1.).x;
				p=clamp((pow(r+.3,2.)-.45),0.,1.);
				return p;
			}
			
			float getVal(float2 pos, float level)
			{
				return length(getCol(pos).xyz)+0.0001*length(pos-0.5*Res0);
				return dot(getCol(pos).xyz,(.333));
			}
			
			float4 getBWDist(float2 pos)
			{
				return (smoothstep(.9,1.1,getVal(pos,0.)*.9+htPattern(pos*.7)));
			}
			
			#define SampNum 24
			
			#define N(a) (a.yx*float2(1,-1))
			
			void mainImage( out float4 fragColor, in float2 fragCoord )
			{
				float2 pos=((fragCoord-Res.xy*.5)/Res.y*Res0.y)+Res0.xy*.5;
				float2 pos2=pos;
				float2 pos3=pos;
				float2 pos4=pos;
				float2 pos0=pos;
				float3 col=(0);
				float3 col2=(0);
				float cnt=0.0;
				float cnt2=0.;
				for(int i=0;i<1*SampNum;i++)
				{
					// gradient for outlines (gray on green screen)
					float2 gr =getGrad(pos, 2.0)+.0001*(getRand(pos ).xy-.5);
					float2 gr2=getGrad(pos2,2.0)+.0001*(getRand(pos2).xy-.5);
					
					// gradient for wash effect (white on green screen)
					float2 gr3=getGrad2(pos3,2.0)+.0001*(getRand(pos3).xy-.5);
					float2 gr4=getGrad2(pos4,2.0)+.0001*(getRand(pos4).xy-.5);
					
					float grl=clamp(10.*length(gr),0.,1.);
					float gr2l=clamp(10.*length(gr2),0.,1.);
					
					// outlines:
					// stroke perpendicular to gradient
					pos +=.8 *normalize(N(gr));
					pos2-=.8 *normalize(N(gr2));
					float fact=1.-float(i)/float(SampNum);
					col+=fact*lerp((1.2),getBWDist(pos).xyz*2.,grl);
					col+=fact*lerp((1.2),getBWDist(pos2).xyz*2.,gr2l);
					
					// colors + wash effect on gradients:
					// color gets lost from dark areas
					pos3+=.25*normalize(gr3)+.5*(getRand(pos0*.07).xy-.5);
					// to bright areas
					pos4-=.5 *normalize(gr4)+.5*(getRand(pos0*.07).xy-.5);
					
					float f1=3.*fact;
					float f2=4.*(.7-fact);
					col2+=f1*(getCol2(pos3).xyz+.25+.4*getRand(pos3*1.).xyz);
					col2+=f2*(getCol2(pos4).xyz+.25+.4*getRand(pos4*1.).xyz);
					
					cnt2+=f1+f2;
					cnt+=fact;
				}
				// normalize
				col/=cnt*2.5;
				col2/=cnt2*1.65;
				
				// outline + color
				col = clamp(clamp(col*.9+.1,0.,1.)*col2,0.,1.);
				// paper color and grain
				col = col*float3(.93,0.93,0.85)
				*lerp(tex2D(TexChannel2,fragCoord.xy/_ScreenParams.xy).xyz,(1.2),.7)
				+.15*getRand(pos0*2.5).x;
				// vignetting
				float r = length((fragCoord-_ScreenParams.xy*.5)/_ScreenParams.x);
				float vign = 1.-r*r*r*r;
				
				fragColor = float4(col*vign,1.0);
			}
			
			
			fixed4 frag (v2f i) : SV_Target
			{
				fixed4 col = 0;
				#if UNITY_UV_STARTS_AT_TOP
				float grabSign = -_ProjectionParams.x;
				#else
				float grabSign = _ProjectionParams.x;
				#endif
				i.screenPos = float4( i.screenPos.xy / i.screenPos.w, 0, 0 );
				i.screenPos.y *= _ProjectionParams.x;
				float2 sceneUVs = float2(1,grabSign)*i.screenPos.xy*0.5+0.5;
				mainImage(col, sceneUVs * _ScreenParams.xy);
				
				return col;
			}
			ENDCG
		}
	}
}

