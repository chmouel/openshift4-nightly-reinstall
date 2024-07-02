{ pkgs, ... }:

{
  packages = with pkgs; [
    apacheHttpd
    git
    openshift
    kubectl
    lego
    awscli2
    apacheHttpd
    fd
  ];
  languages.python = {
    enable = true;
    venv.enable = true;
    venv.requirements = ''
      boto
      pyyaml
    '';
  };

  pre-commit.hooks = {
    shfmt.enable = true;
    shellcheck.enable = true;
    ruff.enable = true;
  };

  enterShell = ''
    export AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id)
    export AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key)
    export AWS_DEFAULT_REGION=$(aws configure get region)
    scripts/generate-ssl-cert.sh
  '';
}
