
namespace ?= camunda

.PHONY: all
all: camunda configmap await-zeebe rebalance-leaders deploy-models benchmark

.PHONY: camunda
camunda:
	helm repo add camunda https://helm.camunda.io
	helm repo update camunda
	helm search repo camunda/camunda-platform
	helm install --namespace $(namespace) camunda camunda/camunda-platform -f ./values.yaml --skip-crds --create-namespace

.PHONY: configmap
configmap:
	kubectl create configmap payload --from-file=./payload.json -n $(namespace)

.PHONY: benchmark
benchmark:
	kubectl apply -f ./benchmark.yaml -n $(namespace)

.PHONY: await-zeebe
await-zeebe:
	kubectl rollout status --watch statefulset/camunda-zeebe --timeout=900s -n $(namespace)


# deploy
#: Deploy BPMN and DMN models using zbctl in a k8s job
deploy-models: job-deploy-models logs-job-deploy-models clean-job-deploy-models

#: Create k8s job to deploy BPMN and DMN models using zbctl
job-deploy-models:
	kubectl create configmap models --from-file=models                    -n $(namespace)
	kubectl apply -f zbctl-deploy-job.yaml                                -n $(namespace)
	kubectl wait --for=condition=complete job/zbctl-deploy --timeout=300s -n $(namespace)

#: Show output of k8s job to deploy BPMN and DMN models using zbctl
logs-job-deploy-models:
	-kubectl logs job.batch/zbctl-deploy -n $(namespace)

#: Delete k8s job to deploy BPMN and DMN models using zbctl
clean-job-deploy-models:
	-kubectl delete configmap models         -n $(namespace)
	-kubectl delete -f zbctl-deploy-job.yaml -n $(namespace)


# rebalance

.PHONY: rebalance-leaders-create
rebalance-leaders-create:
	-kubectl apply -n $(namespace) -f ./rebalance-leader-job.yaml
	-kubectl wait --for=condition=complete job/leader-balancer --timeout=20s -n $(namespace)

.PHONY: rebalance-leaders-delete
rebalance-leaders-delete:
	-kubectl delete -n $(namespace) -f ./rebalance-leader-job.yaml

.PHONY: rebalance-leaders
rebalance-leaders: rebalance-leaders-create rebalance-leaders-delete

# chaos

.PHONY: chaos-mesh
chaos-mesh:
	helm install chaos-mesh chaos-mesh/chaos-mesh --namespace=chaos-mesh --create-namespace --version 2.7.0 --set dashboard.securityMode=false --set chaosDaemon.runtime=containerd --set chaosDaemon.socketPath=/run/containerd/containerd.sock
	kubectl wait --for=condition=Ready pod -n chaos-mesh -l app.kubernetes.io/instance=chaos-mesh --timeout=900s
	kubectl delete validatingWebhookConfigurations.admissionregistration.k8s.io chaos-mesh-validation-auth

# cleanup

.PHONY: clean-camunda
clean-camunda:
	-kubectl delete namespace $(namespace)
	-helm --namespace $(namespace) uninstall camunda
	-kubectl delete -n $(namespace) pvc -l app.kubernetes.io/instance=camunda
	-kubectl delete -n $(namespace) pvc -l app=elasticsearch-master

.PHONY: clean-chaos-mesh
clean-chaos-mesh:
	-helm uninstall chaos-mesh -n chaos-mesh
	-kubectl delete ns chaos-mesh
