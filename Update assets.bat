@echo off
echo -----------------------------------------------------------------------------------------
echo This will delete the assets folder and replace it with the assets from the compiled build
echo This cannot be reverted
echo -----------------------------------------------------------------------------------------
rmdir /s assets
xcopy /e %cd%\export\release\windows\bin\assets\ %cd%\assets\