using System.IO;
using UnityEngine;

[RequireComponent(typeof(Camera))]
public class ShadowMap: MonoBehaviour
{
    public RenderTexture DepthTexture;
    public Camera depthCamera;
    public bool saveDepthTex = false;

    private void OnPreRender()
    {
        BakeDepthTexture();
        UpdateLightMatrix();
    }

    // 保存深度图
    void SaveDepthTexture() {
        RenderTexture old = RenderTexture.active;
        RenderTexture.active = DepthTexture;
        Texture2D tex2D = new Texture2D(DepthTexture.width,DepthTexture.height,TextureFormat.ARGB32,false);
        tex2D.ReadPixels(new Rect(0,0,DepthTexture.width,DepthTexture.height),0,0);
        tex2D.Apply();
        SaveTextureTpPath(tex2D, Application.dataPath + "/deptex.png");
    }

    // 保存Texture到本地
    void SaveTextureTpPath(Texture2D tex, string path)
    {
        FileStream Fs = new FileStream(path, FileMode.Create, FileAccess.Write);
        byte[] bytes = tex.EncodeToPNG();
        Fs.Write(bytes, 0, bytes.Length);
        Fs.Close();
        Fs.Dispose();
    }

    // 根据Transform获取变换矩阵
    Matrix4x4 GetLightProjectMatrix(Camera lightCam)
    {
        Matrix4x4 posToUV = new Matrix4x4();
        posToUV.SetRow(0, new Vector4(0.5f, 0, 0, 0.5f));
        posToUV.SetRow(1, new Vector4(0, 0.5f, 0, 0.5f));
        posToUV.SetRow(2, new Vector4(0, 0, 1, 0));
        posToUV.SetRow(3, new Vector4(0, 0, 0, 1));

        Matrix4x4 worldToView = lightCam.worldToCameraMatrix;
        Matrix4x4 projection = GL.GetGPUProjectionMatrix(lightCam.projectionMatrix, false);

        return projection * worldToView;
    }
    
    [ContextMenu("烘焙深度图")]
    void BakeDepthTexture() {
        
        if (null == depthCamera)
        {
            depthCamera = GetComponent<Camera>();
        }

        if (DepthTexture)
        {
            RenderTexture.ReleaseTemporary(DepthTexture);
            DepthTexture = null;
        }
        depthCamera.backgroundColor = Color.clear;
        depthCamera.clearFlags = CameraClearFlags.SolidColor;
        DepthTexture = RenderTexture.GetTemporary(depthCamera.pixelWidth, depthCamera.pixelHeight, 16, RenderTextureFormat.ARGB32);
        depthCamera.targetTexture = DepthTexture;
        Shader.SetGlobalTexture("_LightDepthTex", DepthTexture);

        Shader depthShader = Shader.Find("XHShaderLab/CaptureDepth");
        depthCamera.RenderWithShader(depthShader, "RenderType");

        if (saveDepthTex)
        {
           saveDepthTex = false;
            SaveDepthTexture();
        }
    }
    [ContextMenu("更新光源矩阵")]
    void UpdateLightMatrix() {
        Shader.SetGlobalMatrix("_LightProjection", GetLightProjectMatrix(depthCamera));
    }
}