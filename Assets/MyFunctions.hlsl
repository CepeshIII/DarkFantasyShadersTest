float2 textureSize = _BlitTexture_TexelSize.zw;
float minSize = min(textureSize.x, textureSize.y);
float2 squareUVFactor = textureSize / minSize;