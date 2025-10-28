using Unity.Cinemachine;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.Rendering.Universal;


public class PlayerController : MonoBehaviour
{
    private CharacterController controller;
    public CinemachineImpulseSource impulseSource;

    public float maxTimeBetweenStepImpulse = 1f;
    public float timeBetweenStepImpulse;
    public bool lastStepWasRight = false;

    public float playerSpeed = 5.0f;
    public float runMultiplayer = 3f;
    public float jumpHeight = 1.5f;
    public float gravityValue = -9.81f;
    public float rotationSpeed = 500.0f; // Speed for rotation

    public float amplitudeX = 0.3f;
    public float amplitudeY = 0.3f;
    public float amplitudeZ = 0.0f;


    [Header("Input Actions")]
    public InputActionReference moveAction; // expects Vector2
    public InputActionReference jumpAction; // expects Button
    public InputActionReference lookAction; // expects Vector2 for mouse/joystick look\
    public InputActionReference runAction; // expects Vector2 for mouse/joystick look\
    public InputActionReference changeStateOfPostProcess; // expects Vector2 for mouse/joystick look\

    public float Amplitude; // expects Vector2 for mouse/joystick look
    public float Frequency; // expects Vector2 for mouse/joystick look

    public AnimationCurve stepCurveX;
    public AnimationCurve stepCurveY;
    public AnimationCurve stepCurveZ;

    private Vector3 playerVelocity;
    private bool groundedPlayer;
    private Camera mainCamera;
    private Vector3 cameraOffset;



    private void Awake()
    {
        controller = gameObject.AddComponent<CharacterController>();

    }

    private void OnEnable()
    {
        moveAction.action.Enable();
        jumpAction.action.Enable();
        lookAction.action.Enable();
        changeStateOfPostProcess.action.Enable();
        runAction.action.Enable();
    }

    private void OnDisable()
    {
        moveAction.action.Disable();
        jumpAction.action.Disable();
        lookAction.action.Disable();
        changeStateOfPostProcess.action.Disable();
        runAction.action.Disable();
    }


    public void Start()
    {
        mainCamera = Camera.main;
        cameraOffset = mainCamera.transform.localPosition;
        foreach (var t in stepCurveY.keys)
        {
            Debug.Log($"{t.time}, {t.value}, {t.inTangent}, {t.outTangent}");
            //Debug.Log($"t.time: {t.time}, value: {t.value}, inTangent: {t.inTangent}, inWeight: {t.outTangent}");
        }

    }


    void Update()
    {
        groundedPlayer = controller.isGrounded;
        if (groundedPlayer && playerVelocity.y < 0)
        {
            playerVelocity.y = 0f;
        }


        bool playerRunning = runAction.action.IsPressed();
        // Movement Input
        Vector2 movementInput = moveAction.action.ReadValue<Vector2>();
        Vector3 move = transform.right * movementInput.x + transform.forward * movementInput.y;
        var speed = playerSpeed;
        if (playerRunning) 
        {
            speed *= runMultiplayer;
        }
        controller.Move(move * speed * Time.deltaTime);

        timeBetweenStepImpulse -= Time.deltaTime;

        if (movementInput.magnitude > 0 && timeBetweenStepImpulse < 0) 
        {
            //var time = Time.time;
            //var x = mainCamera.transform.localPosition.y + Amplitude * stepCurveX.Evaluate(Frequency * time);
            //var y = mainCamera.transform.localPosition.x + Amplitude * stepCurveY.Evaluate(Frequency * time);
            //var z = mainCamera.transform.localPosition.z + Amplitude * stepCurveZ.Evaluate(Frequency * time);
            float xImpulse;
            if (lastStepWasRight)
            {
                xImpulse = -amplitudeX;
            }
            else
            {
                xImpulse = amplitudeX;
            }

            if(impulseSource != null)
                impulseSource.GenerateImpulseWithVelocity(transform.rotation * new Vector3(xImpulse, -amplitudeY, amplitudeZ));
            timeBetweenStepImpulse = maxTimeBetweenStepImpulse;
            lastStepWasRight = !lastStepWasRight;
            //mainCamera.transform.localPosition = new Vector3(x, y, z);
        }
        else
        {
            //lastStepWasRight = false;
            mainCamera.transform.localPosition = Vector3.Lerp(mainCamera.transform.localPosition, cameraOffset, 0.1f);
        }



        // Jump Input
        if (jumpAction.action.triggered && groundedPlayer)
        {
            playerVelocity.y += Mathf.Sqrt(jumpHeight * -3.0f * gravityValue);
        }

        playerVelocity.y += gravityValue * Time.deltaTime;
        controller.Move(playerVelocity * Time.deltaTime);

        // Rotation Input (e.g., mouse look)
        Vector2 lookInput = lookAction.action.ReadValue<Vector2>();
        transform.Rotate(Vector3.up * lookInput.x * rotationSpeed * Time.deltaTime); // Yaw (Y-axis rotation)
        // For pitch (X-axis rotation, usually applied to a child camera):
        mainCamera.transform.Rotate(Vector3.left * lookInput.y * rotationSpeed * Time.deltaTime);


        if (changeStateOfPostProcess.action.triggered) 
        {
            var cameraData = mainCamera.GetUniversalAdditionalCameraData();
            cameraData.renderPostProcessing = !cameraData.renderPostProcessing;
        }
    }
}