**DOES NOT WORK WITH NWN:EE**

Hi.

This is a plugin that does a bunch of jank stuff to nwmain.
It loads a full Lua environment that is also extended by a lot of other functionalities such as http.

I take no responsbilities for anything going wrong with this. Do not run lua code that you are not comfortable with.

You have been warned.

Install:

1: Open sinfarx.ini (in your nwn folder) and change:

LoadAllNWNCXPlugins=0

TO:

LoadAllNWNCXPlugins=1

Save.

2: drop the .dll files into the same folder as nwmain.exe.

3: You can try starting, if it works then a console window should pop downloading the scripts from https://github.com/TerrahKitsune/nwncx_lua_script

4: If it doesnt then try installing the runtimes VC_redist.x86.exe that was included.