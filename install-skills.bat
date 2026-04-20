@echo off
echo Copying skills to user profile...
xcopy /E /I /Y "%~dp0.agents-copilot\skills" "%USERPROFILE%\.agents\skills"
echo Skills copied successfully.