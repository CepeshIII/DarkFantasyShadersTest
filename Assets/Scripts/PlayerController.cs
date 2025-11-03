using Unity.Cinemachine;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.Rendering.Universal;


public class PlayerController : MonoBehaviour
{
    [SerializeField] private CharacterController controller;
    [SerializeField] private CinemachineImpulseSource impulseSource;
    [SerializeField] private float maxTimeBetweenStepImpulse = 1f;
    [SerializeField] private float timeBetweenStepImpulse;
    [SerializeField] private bool lastStepWasRight = false;
    [SerializeField] private float playerSpeed = 5.0f;
    [SerializeField] private float runMultiplayer = 3f;
    [SerializeField] private float jumpHeight = 1.5f;
    [SerializeField] private float gravityValue = -9.81f;
    [SerializeField] private float amplitudeX = 0.3f;
    [SerializeField] private float amplitudeY = 0.3f;
    [SerializeField] private float amplitudeZ = 0.0f;


    [Header("Input Actions")]
    [SerializeField] private InputActionReference moveAction; // expects Vector2
    [SerializeField] private InputActionReference jumpAction; // expects Button
    [SerializeField] private InputActionReference lookAction; // expects Vector2 for mouse/joystick look\
    [SerializeField] private InputActionReference runAction; // expects Vector2 for mouse/joystick look\
    [SerializeField] private InputActionReference changeStateOfPostProcess; // expects Vector2 for mouse/joystick look\

    [SerializeField] private float Amplitude; // expects Vector2 for mouse/joystick look
    [SerializeField] private float Frequency; // expects Vector2 for mouse/joystick look


    [Header("Rotating Settings")]
    [SerializeField] private bool invertY;
    [SerializeField] private float rotationSpeed = 500.0f; // Speed for rotation
    [SerializeField] private float pitchClamp = 80f;


    private Camera mainCamera;
    private Vector3 cameraOffset;
    private Vector3 playerVelocity;
    private Vector3 currentLook = Vector3.forward;

    private bool groundedPlayer;

    private float yaw = 0f;
    private float pitch = 0f;



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
    }


    void Update()
    {
        CameraAndPlayerRotation();
        PlayerMovement();

        if (changeStateOfPostProcess.action.triggered) 
        {
            var cameraData = mainCamera.GetUniversalAdditionalCameraData();
            cameraData.renderPostProcessing = !cameraData.renderPostProcessing;
        }
    }

    private void CameraAndPlayerRotation()
    {
        Vector2 lookInput = lookAction.action.ReadValue<Vector2>();
        lookInput *= rotationSpeed * Time.deltaTime;

        // Apply inversion
        if (invertY) lookInput.y = -lookInput.y;

        // Smooth camera look (optional but nice)
        currentLook = lookInput;

        // Apply yaw and pitch
        yaw += currentLook.x;
        pitch -= currentLook.y;
        pitch = Mathf.Clamp(pitch, -pitchClamp, pitchClamp);

        // Rotate player body (yaw)
        transform.rotation = Quaternion.Euler(0f, yaw, 0f);

        // Rotate camera holder (pitch)
        mainCamera.transform.localRotation = Quaternion.Euler(pitch, 0f, 0f);
    }

    private void PlayerMovement()
    {
        groundedPlayer = controller.isGrounded;
        bool playerRunning = runAction.action.IsPressed();

        if (groundedPlayer && playerVelocity.y < 0)
        {
            playerVelocity.y = 0f;
        }

        // Movement Input
        Vector2 movementInput = moveAction.action.ReadValue<Vector2>();
        Vector3 move = transform.right * movementInput.x + transform.forward * movementInput.y;
        var speed = playerSpeed;
        if (playerRunning)
        {
            speed *= runMultiplayer;
        }
        controller.Move(move * speed * Time.deltaTime);

        CameraBobbing(movementInput);

        // Jump Input
        if (jumpAction.action.triggered && groundedPlayer)
        {
            playerVelocity.y += Mathf.Sqrt(jumpHeight * -3.0f * gravityValue);
        }

        playerVelocity.y += gravityValue * Time.deltaTime;
        controller.Move(playerVelocity * Time.deltaTime);
    }


    private void CameraBobbing(Vector2 movementInput)
    {
        timeBetweenStepImpulse -= Time.deltaTime;

        if (movementInput.magnitude > 0 && timeBetweenStepImpulse < 0)
        {
            float xImpulse;
            if (lastStepWasRight)
            {
                xImpulse = -amplitudeX;
            }
            else
            {
                xImpulse = amplitudeX;
            }

            if (impulseSource != null)
                impulseSource.GenerateImpulseWithVelocity(transform.rotation * new Vector3(xImpulse, -amplitudeY, amplitudeZ));
            timeBetweenStepImpulse = maxTimeBetweenStepImpulse;
            lastStepWasRight = !lastStepWasRight;
        }
        else
        {
            mainCamera.transform.localPosition = Vector3.Lerp(mainCamera.transform.localPosition, cameraOffset, 0.1f);
        }
    }


}