{ pkgs, lib, config, inputs, ... }:

{
  packages = with pkgs; [
    apacheHttpd
    openshift
    kubectl
    lego
    awscli2
    apacheHttpd
  ];
  languages.python = {
    enable = true;
    venv.enable = true;
    venv.requirements = ''
      boto
      pyyaml
    '';
  };

  pre-commit.hooks.shellcheck.enable = true;
  enterShell = ''
    export AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id)
    export AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key)
    export AWS_DEFAULT_REGION=$(aws configure get region)
    scripts/generate-ssl-cert.sh
  '';

  # https://devenv.sh/processes/
  # processes.ping.exec = "ping example.com";

  # See full reference at https://devenv.sh/reference/options/
}