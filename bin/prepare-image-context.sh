#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
stack="$root/../dateninfrastruktur-dev-stack"
plugin="$root/../dateninfrastruktur-jenkins-gretl-plugin"
topics="$root/../dateninfrastruktur-themenrepo"
context="${1:?Explicit new build context directory required}"
[[ ! -e "$context" ]] || { printf 'Build context already exists; no overwrite.\n' >&2; exit 1; }
mkdir -p "$context"
chmod 0700 "$context"
if [[ -n "${DI_GRETL_SNAPSHOT_VERSION:-}" ]]; then
    snapshot="$(python3 "$root/bin/resolve-gretl.py" "$DI_GRETL_SNAPSHOT_VERSION")"
    read -r gretl_version gretl_sha256 <<< "$snapshot"
    [[ "$gretl_sha256" == "${DI_GRETL_SNAPSHOT_SHA256:?Missing checksum for the CI snapshot}" ]] || {
        printf 'GRETL snapshot checksum changed: %s\n' "$gretl_version" >&2
        exit 1
    }
else
    snapshot="$(python3 "$root/bin/resolve-gretl.py")"
    read -r gretl_version gretl_sha256 <<< "$snapshot"
fi
source "$root/bin/java-env.sh"
activate_java_home "$(resolve_java_home 21 JAVA21_HOME 'Java 21 for the Jenkins HPI')"
(cd "$plugin" && mvn -ntp clean package)
cp "$root/Dockerfile" "$root/plugins.txt" "$root/docker-entrypoint.sh" "$root/gretl-bundle.gradle" "$root/oidc-plugin.sha256" "$context/"
cp "$stack/services/jenkins/jenkins-stack.yaml" "$context/jenkins.yaml"
cp "$plugin/target/jenkins-gretl-dateninfrastruktur-plugin.hpi" "$context/delivery.jpi"
mkdir "$context/runner-bundle"
git -C "$topics" archive HEAD -- contracts models runner | tar -x -C "$context/runner-bundle"
python3 - "$context" "$stack" "$plugin" "$topics" "${IMAGE_VERSION:-local}" "$gretl_version" "$gretl_sha256" <<'PY'
import hashlib,json,pathlib,subprocess,sys
context,stack,plugin,topics=map(pathlib.Path,sys.argv[1:5])
head=lambda repo:subprocess.check_output(['git','-C',str(repo),'rev-parse','HEAD'],text=True).strip()
args={'JENKINS_IMAGE':'jenkins/jenkins:2.555.2-lts-jdk21@sha256:01c992ffef29dcf41c7164e8c16285c657c2368c4943dda8d68c93fdf54447d5','IMAGE_VERSION':sys.argv[5],'PLUGIN_VERSION':'0.2.0-SNAPSHOT','GRETL_VERSION':sys.argv[6],'GRETL_SHA256':sys.argv[7],'THEMEN_REPO_REVISION':head(topics),'PLUGIN_REPO_REVISION':head(plugin),'PLUGIN_HPI_SHA256':hashlib.sha256((context/'delivery.jpi').read_bytes()).hexdigest()}
bundle=context/'runner-bundle'
files={f.relative_to(bundle).as_posix():hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(bundle.rglob('*')) if f.is_file()}
canonical=lambda data:json.dumps(data,sort_keys=True,separators=(',',':')).encode()
revisions={'topics':head(topics),'plugin':head(plugin),'stack':head(stack),'jenkins':head(stack.parent/'dateninfrastruktur-jenkins-dev')}
provenance={'runnerSha256':hashlib.sha256(canonical(files)).hexdigest(),'repositorySha256':hashlib.sha256(canonical(revisions)).hexdigest()}
(context/'runner-provenance.json').write_bytes(canonical(provenance)+b'\n')
(context/'build-args.json').write_text(json.dumps(args,indent=2)+'\n')
PY
