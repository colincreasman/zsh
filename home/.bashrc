# ~/.bashrc - symlinked from zsh-config/home/.bashrc by install.sh.

# glog-dir (zsh/git-dirlog.sh) is shared with the zsh config. Find the repo
# through this file's symlink so it keeps working wherever the repo lives.
_zc_rc=${BASH_SOURCE[0]}
if [ -L "$_zc_rc" ]; then
    _zc_target=$(readlink "$_zc_rc")
    case $_zc_target in
        /*) _zc_rc=$_zc_target ;;
        *)  _zc_rc=$(dirname "$_zc_rc")/$_zc_target ;;
    esac
fi
_zc_dir=$(cd "$(dirname "$_zc_rc")/.." 2>/dev/null && pwd)
[ -r "$_zc_dir/zsh/git-dirlog.sh" ] || _zc_dir=${ZSH_CONFIG:-}
[ -r "$_zc_dir/zsh/git-dirlog.sh" ] && . "$_zc_dir/zsh/git-dirlog.sh"
unset _zc_rc _zc_target _zc_dir
