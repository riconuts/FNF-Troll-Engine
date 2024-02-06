:: What this does: Deletes assets folder and copies the assets from the compiled build
rmdir /s assets
xcopy /e %cd%\export\release\windows\bin\assets\ %cd%\assets\