# History

```sh
# Extract all tasks from history
awk "/^[[:space:]]*(\\[ \\]|\\[x\\]|\\[-\])/ {print}" $HISTORY

# Extract all unfinished tasks from history 
awk "/^[[:space:]]*(\\[ \\]|\\[-\])/ {print}" $HISTORY

# Extract all active tasks from history
awk "/^[[:space:]]*(\\[-\])/ {print}" $HISTORY
```
