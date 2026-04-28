codex_commit() {
    logfile=$(mktemp)
    echo $logfile
    codex exec "$@" 2>&1 | tee $logfile                        
    msg=$(awk '/^codex$/ { x=""; next } { x=x $0 ORS } END { print x }' $logfile )
    git commit --allow-empty -m "finished: codex exec \"$*\"
    Codex output: $msg"
}

codex_commit_push() {
    git pull
    codex_commit "$@"
    git push
}
