wget https://raw.githubusercontent.com/rancher/system-upgrade-controller/refs/heads/master/manifests/system-upgrade-controller.yaml

kubectl apply -f roles.yaml
kubectl apply -f system-upgrade-controller.yaml
