{ pkgs, lib, ... }:

{
  services.k3s = {
    enable = true;
    extraFlags = toString [ "--write-kubeconfig-mode 644" ];
  };

  environment.systemPackages = with pkgs; [
    kubectl
    kubernetes-helm
    k9s
    kubectx
  ];

  systemd.services.k3s.wantedBy = lib.mkForce [ ];

  networking.firewall.trustedInterfaces = [
    "cni0"
    "flannel.1"
  ];

  environment.variables.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";

  environment.shellAliases = {
    "microk8s.start" = "echo 'K3s is running via systemd'";
    "microk8s.config" = "cat /etc/rancher/k3s/k3s.yaml";
    "microk8s.enable" = "true";
    "microk8s.kubectl" = "kubectl";
    "microk8s.helm3" = "helm";
  };
}
