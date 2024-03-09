using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[ExecuteAlways]
public class PlanarReflection_URP : MonoBehaviour
{
    private Camera reflectionCamera = null;
    private RenderTexture reflectionRT = null;
    private Material reflectionMaterial = null;

    private Camera Target
    {
        get
        {
            return Camera.main;
        }
    }

    void OnEnable()
    {
        RenderPipelineManager.beginCameraRendering += BeginCameraRendering;
    }

    void OnDisable()
    {
        RenderPipelineManager.beginCameraRendering -= BeginCameraRendering;
        if (reflectionRT)
        {
            reflectionCamera.targetTexture = null;
            DestroyImmediate(reflectionRT);
            reflectionRT = null;
        }
        if (reflectionCamera)
        {
            DestroyImmediate(reflectionCamera.gameObject);
            reflectionCamera = null;
        }
    }

    private void BeginCameraRendering(ScriptableRenderContext context, Camera camera)
    {
        //创建自己的反射相机
        if (reflectionCamera == null)
        {
            GameObject go = new GameObject("reflect camera");
            go.hideFlags = HideFlags.HideAndDontSave;
            reflectionCamera = go.AddComponent<Camera>();
            reflectionCamera.CopyFrom(Target);
        }
        //创建自己的RT
        if (reflectionRT == null)
        {
            reflectionRT = RenderTexture.GetTemporary(1024, 1024, 24);
            reflectionRT.name = "_MirrorReflection" + GetInstanceID();
            reflectionRT.isPowerOfTwo = true;
            reflectionRT.hideFlags = HideFlags.DontSave;
            reflectionRT.antiAliasing = 1;
        }
        if (Target == null)
            return;
        //更新相机设置
        UpdateCameraModes(Target, reflectionCamera);
        reflectionCamera.targetTexture = reflectionRT;
        reflectionCamera.enabled = false;
        //使用法向量，和平面上一点，得到反射矩阵
        var reflectM = CalculateReflectionMatrix(transform.up, transform.position);
        reflectionCamera.worldToCameraMatrix = Target.worldToCameraMatrix * reflectM;

        //改变投影矩阵，裁剪平面下方像素
        var normal = transform.up;
        var d = -Vector3.Dot(normal, transform.position);
        var plane = new Vector4(normal.x, normal.y, normal.z, d);
        //用逆转置矩阵将平面从世界空间变换到反射相机空间
        var viewSpacePlane = reflectionCamera.worldToCameraMatrix.inverse.transpose * plane;
        var clipMatrix = reflectionCamera.CalculateObliqueMatrix(viewSpacePlane);
        reflectionCamera.projectionMatrix = clipMatrix;

        //背面裁剪反置
        GL.invertCulling = true;
        UniversalRenderPipeline.RenderSingleCamera(context, reflectionCamera);
        GL.invertCulling = false;

        if (reflectionMaterial == null)
        {
            var renderer = GetComponent<Renderer>();
            reflectionMaterial = renderer.sharedMaterial;
        }
        reflectionMaterial.SetTexture("_ReflectionTex", reflectionRT);

    }

    private void UpdateCameraModes(Camera src, Camera dest)
    {
        if (dest == null || src == null)
            return;

        dest.clearFlags = src.clearFlags;
        dest.backgroundColor = src.backgroundColor;
        dest.farClipPlane = src.farClipPlane;
        dest.nearClipPlane = src.nearClipPlane;
        dest.orthographic = src.orthographic;
        dest.fieldOfView = src.fieldOfView;
        dest.aspect = src.aspect;
        dest.orthographicSize = src.orthographicSize;

    }

    private static Matrix4x4 CalculateReflectionMatrix(Vector3 normal, Vector3 postionOnPlane)
    {
        Matrix4x4 reflectionMat = new Matrix4x4();
        float d = -Vector3.Dot(normal, postionOnPlane);
        reflectionMat.m00 = (1F - 2F * normal[0] * normal[0]);
        reflectionMat.m01 = (-2F * normal[0] * normal[1]);
        reflectionMat.m02 = (-2F * normal[0] * normal[2]);
        reflectionMat.m03 = (-2F * d * normal[0]);

        reflectionMat.m10 = (-2F * normal[1] * normal[0]);
        reflectionMat.m11 = (1F - 2F * normal[1] * normal[1]);
        reflectionMat.m12 = (-2F * normal[1] * normal[2]);
        reflectionMat.m13 = (-2F * d * normal[1]);

        reflectionMat.m20 = (-2F * normal[2] * normal[0]);
        reflectionMat.m21 = (-2F * normal[2] * normal[1]);
        reflectionMat.m22 = (1F - 2F * normal[2] * normal[2]);
        reflectionMat.m23 = (-2F * d * normal[2]);

        reflectionMat.m30 = 0F;
        reflectionMat.m31 = 0F;
        reflectionMat.m32 = 0F;
        reflectionMat.m33 = 1F;
        return reflectionMat;
    }
}
