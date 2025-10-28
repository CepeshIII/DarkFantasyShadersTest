
// "notebook drawings" by florian "flockaroo" berger @ https://www.shadertoy.com/view/XtVGD1
// Use this code in accordance to the license holder's license !



Shader "ImageFilter/NotebookDrawings"
{
	Properties
	{
		TexChannel1 ("Texture1", 2D) = "white" {}
		SampNum ("Sample Count", float) = 16
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
			
			// trying to resemle some hand drawing style
			
			
			#define SHADERTOY
			#ifdef SHADERTOY
			#define Res0 TexChannel0_TexelSize.zwxy.xy
			#define Res1 TexChannel1_TexelSize.zwxy.xy
			#else
			#define Res0 textureSize(TexChannel0,0)
			#define Res1 textureSize(TexChannel1,0)
			#define _ScreenParams Res0
			#endif
			
			#define Res  _ScreenParams.xy
			
			#define randSamp TexChannel1
			#define colorSamp TexChannel0
			
			
			float4 getRand(float2 pos)
			{
				return tex2Dlod(TexChannel1, float4(pos/Res1/_ScreenParams.y*1080., 0, 0.0));
			}
			
			float4 getCol(float2 pos)
			{
				// take aspect ratio into account
				float2 uv=((pos-Res.xy*.5)/Res.y*Res0.y)/Res0.xy+.5;
				float4 c1=tex2D(TexChannel0,uv);
				float4 e=smoothstep((-0.05),(-0.0),float4(uv,(1)-uv));
				c1=lerp(float4(1,1,1,0),c1,e.x*e.y*e.z*e.w);
				float d=clamp(dot(c1.xyz,float3(-.5,1.,-.5)),0.0,1.0);
				float4 c2=(.7);
				return min(lerp(c1,c2,1.8*d),.7);
			}
			
			float4 getColHT(float2 pos)
			{
				return smoothstep(.95,1.05,getCol(pos)*.8+.2+getRand(pos*.7));
			}
			
			float getVal(float2 pos)
			{
				float4 c=getCol(pos);
				return pow(dot(c.xyz,(.333)),1.)*1.;
			}
			
			float2 getGrad(float2 pos, float eps)
			{
				float2 d=float2(eps,0);
				return float2(
				getVal(pos+d.xy)-getVal(pos-d.xy),
				getVal(pos+d.yx)-getVal(pos-d.yx)
				)/eps/2.;
			}
			
			#define AngleNum 3
			
			int SampNum;
			#define PI2 6.28318530717959
			
			void mainImage( out float4 fragColor, in float2 fragCoord )
			{
				float2 pos = fragCoord+4.0*sin(_Time.r*1.*float2(1,1.7))*_ScreenParams.y/400.;
				float3 col = (0);
				float3 col2 = (0);
				float sum=0.;
				for(int i=0;i<AngleNum;i++)
				{
					float ang=PI2/float(AngleNum)*(float(i)+.8);
					float2 v=float2(cos(ang),sin(ang));
					for(int j=0;j<SampNum;j++)
					{
						float2 dpos  = v.yx*float2(1,-1)*float(j)*_ScreenParams.y/400.;
						float2 dpos2 = v.xy*float(j*j)/float(SampNum)*.5*_ScreenParams.y/400.;
						float2 g;
						float fact;
						float fact2;
						
						for(float s=-1.;s<=1.;s+=2.)
						{
							float2 pos2=pos+s*dpos+dpos2;
							float2 pos3=pos+(s*dpos+dpos2).yx*float2(1,-1)*2.;
							g=getGrad(pos2,.4);
							fact=dot(g,v)-.5*abs(dot(g,v.yx*float2(1,-1)))/**(1.-getVal(pos2))*/;
							fact2=dot(normalize(g+(.0001)),v.yx*float2(1,-1));
							
							fact=clamp(fact,0.,.05);
							fact2=abs(fact2);
							
							fact*=1.-float(j)/float(SampNum);
							col += fact;
							col2 += fact2*getColHT(pos3).xyz;
							sum+=fact2;
						}
					}
				}
				col/=float(SampNum*AngleNum)*.75/sqrt(_ScreenParams.y);
				col2/=sum;
				col.x*=(.6+.8*getRand(pos*.7).x);
				col.x=1.-col.x;
				col.x*=col.x*col.x;
				
				float2 s=sin(pos.xy*.1/sqrt(_ScreenParams.y/400.));
				float3 karo=(1);
				karo-=.5*float3(.25,.1,.1)*dot(exp(-s*s*80.),(1));
				float r=length(pos-_ScreenParams.xy*.5)/_ScreenParams.x;
				float vign=1.-r*r*r;
				fragColor = float4((col.x*col2*karo*vign),1);
				//fragColor=getCol(fragCoord);
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

