#!/bin/bash
SESSIONNAME="operator"

tmux has-session -t "${SESSIONNAME}" &> /dev/null || {
    tmux new-session -s "${SESSIONNAME}" -n website -d

    # Create a split pane for the website logs
    tmux split-window -v -t "${SESSIONNAME}:website"
    tmux send-keys -t "${SESSIONNAME}:website.0" "journalctl -u website.service -f" Enter
    tmux select-pane -t "${SESSIONNAME}:website.1"

    # Create a split pane for the minecraft logs
    tmux new-window -t "${SESSIONNAME}" -n minecraft
    tmux split-window -v -t "${SESSIONNAME}:minecraft"
    tmux send-keys -t "${SESSIONNAME}:minecraft.0" "journalctl -u minecraft.service -f" Enter
    tmux select-pane -t "${SESSIONNAME}:minecraft.1"

    # Create a split pane for the minecraft (modded) logs
    tmux new-window -t "${SESSIONNAME}" -n minecraft-modded
    tmux split-window -v -t "${SESSIONNAME}:minecraft-modded"
    tmux send-keys -t "${SESSIONNAME}:minecraft-modded.0" "journalctl -u minecraft-modded.service -f" Enter
    tmux select-pane -t "${SESSIONNAME}:minecraft-modded.1"

    # Create a split pane for the backup manager logs
    tmux new-window -t "${SESSIONNAME}" -n  backup-manager -d
    tmux split-window -v -t "${SESSIONNAME}:backup-manager"
    tmux send-keys -t "${SESSIONNAME}:backup-manager.0" "journalctl -u backup-create.service -f" Enter
    tmux select-pane -t "${SESSIONNAME}:backup-manager.1"
}

tmux attach-session -t "${SESSIONNAME}"