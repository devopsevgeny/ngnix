# Suggestions

### Project
Missing md files
  - task
  - contributors
  - readme file is not informative at all
  - 

### README
- Missing link to
  - INSTALL.md
  - CONTRIBUTORS.md
  - TASKS.md
- Missing :
  - explaination
  - documentation
  - usage
  - validation
  - dependencies of OS
  - which linux.


### SCRIPT
- lines 17-21, globally declared variable need to be with Capital letters - FIXED
- functions suppose to start with word `function` in them  - FIXED 
- help function : use single `printf` command to format the whole output and exit with 0 by the end of it. -FIXED
- you are suppose to us [[ and not [ - Fixed 
- what other way you can get password from user? password=$(dialog --passwordbox "Enter password:" 8 30 --stdout) 
- why not use EUID, and run as root, instead of using so many `sudo` commands ? Please answer me in PR
- main function, missing version and verbose optiions
- main function, what happens if i run option in incorrect flow ? please answer in PR
- main function, there is no validation on each of the steps, whether they fail of succeed, how do you know that function ran successfully ? please answer in PR
- why not use template files instead of EOF/EOL ? please answer in PR
