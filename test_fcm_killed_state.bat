@echo off
echo ==============================================
echo SafeNet FCM Killed State Diagnostic Script
echo ==============================================
echo.
echo Make sure your phone is connected and USB debugging is ON.
echo Proceeding in 3 seconds...
timeout /t 3 >nul

echo 1. Finding SafeNet App...
"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" shell pm path com.example.safenetai >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] SafeNet AI is not installed on this device.
    pause
    exit /b
)
echo [OK] App found.

echo 2. Forcing App into Background (Simulating Home Button)...
"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" shell input keyevent KEYCODE_HOME
timeout /t 2 >nul

echo 3. Force-Stopping the app to simulate a swipe-kill...
"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" shell am force-stop com.example.safenetai
timeout /t 2 >nul

echo 4. Forcing device into DOZE (Deep Sleep) mode...
"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" shell dumpsys deviceidle force-idle
echo [OK] Device is now asleep.

echo.
echo ==============================================
echo SYSTEM IS READY FOR TESTING
echo ==============================================
echo Please go to your Firebase Console or trigger
echo a Cloud Function to send a PANIC ALERT now.
echo.
echo IF THE SCREEN LIGHTS UP WITH A NOTIFICATION:
echo - Your Server JSON is correct.
echo - Your AndroidManifest is correct.
echo.
echo IF NOTHING HAPPENS:
echo - The manufacturer (Xiaomi/Vivo/Oppo) is hard-blocking Firebase.
echo - You MUST go to Settings -> Apps -> SafeNet AI -> Battery
echo   and set it to 'Unrestricted', then turn on 'AutoStart'.
echo.
echo Press any key to awaken the device and restore normal battery state.
pause

echo Waking device up...
adb shell dumpsys deviceidle unforce
echo Done. You may close this window.
pause
