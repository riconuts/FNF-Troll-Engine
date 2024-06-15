@echo off
cd ..

echo -----------------------------------------------------------------------------------------
echo This will delete the assets folder and replace it with the assets from the compiled build
echo This cannot be reverted
echo -----------------------------------------------------------------------------------------

set /p confirm="Are you sure you'd like to do this? (Y/N)"
if confirm == "y" set confirm="Y"

if confirm == "Y" (
exit

) else (

rmdir /s /q assets
xcopy /e %cd%\export\release\windows\bin\assets\ %cd%\assets\
)