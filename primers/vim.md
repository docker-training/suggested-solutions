# VIM Primer

By the end of this primer, you should be able to:

 - Open vim
 - Switch between insert and command mode
 - Save and quit
 - Quit without saving
 - Disaster Recovery

## Basics of vim

Vim is a powerful text editor used in CLI that has a particular working method. Vim has two modes:

 - Command Mode: When you start vim, you are placed in Command mode. In this mode, you can move across the screen and delete and copy text.
 - Insert Mode: You cannot write text in command mode. To insert text, there is a dedicated insert mode.

 1.  To open vim, you will need to enter:

    ```bash
    vim <name of file>
    ```

    If a file does not exist in your currently directory with the same name, it will be created automatically.

2.  You will start in command mode. To enter into insert mode, press the `i` key. You will see `-- INSERT --` at the bottom of the terminal screen indicating that you are in insert mode.

3.  If you would like to go back to command mode, press the escape key.

4.  When you are in vim, you cannot use your mouse to click at a point in the screen like code editors. Using the arrow keys will allow you to navigate throughout the file.

5.  To save and/or quit vim, you must enter the command mode first by pressing the escape key. And then you can use the following options:
    
    - :w - Save the changes but don't exit
    - :wq - Save and quit
    - :q - Just quit (if you have unsaved changes, you'll see this warning: E37: No write since last change (add ! to override))
    - :q! - Force quit (it will discard any unsaved changes)

6.  In case anything happens, such as your computer crashing, you can recover most of your changes from the files that vim uses to store the contents of this file. Mostly you can recover your work with one command:

    ```bash
    vim -r <file name>
    ```

    More information can be found here: [Disaster Recovery](http://vimdoc.sourceforge.net/htmldoc/recover.html)

