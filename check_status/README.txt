[How to use]
1. Define hostfile first.
   ex) # cat hostfile
         mdw
         smdw
         sdw1
         sdw2
         sdw3
         sdw4

2. sshpass package must be installed.
   Modify password on line 8
   If do not use sshpass, edit lines 432-438

3. The execution is as follows.
   > ./check_st.sh hostfile
