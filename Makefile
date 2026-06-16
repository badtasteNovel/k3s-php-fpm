 SHELL  := /bin/sh
# 定義執行對象

#EXEC_ROOT = docker compose -f docker-compose-web-server.yaml exec -u root php-fpm

#EXEC_WORK_ROOT = docker compose -f docker-compose-web-server.yaml exec -w /var/www/html -u root php-fpm
# --rm: 執行完秒刪容器
# nginx_proxy_certs:/target 把名為 nginx_proxy_certs 的具名卷掛載到容器內的 /target 路徑。 target 為虛擬路徑，因為容器刪除就消失了。所有東西已經被搬到具名捲上。
# -v $(pwd)/certs:/source 掛載來源路徑 把你目前所在的 certs 資料夾掛載到容器內的 /source 路徑。
.PHONY: init-dev init-all \
        build-nginx-php-fpm install-composer-environment-setup \
        deploy deploy-dev start-service start-service-dev

build-image-dev:
	@echo "📦 封裝 Web Server 鏡像..."
	docker compose -f docker-compose-web-server.yaml -f docker-compose-web-server-override.yaml build
	docker compose -f docker-compose-service-server.yaml build
build-image-prod:
	@echo "📦 封裝 Web Server 鏡像..."
	docker compose -f docker-compose-web-server.yaml build
	docker compose -f docker-compose-service-server.yaml build
import-image:
	k3d image import nginx-proxy:latest php-fpm:latest reverb:latest -c dev-cluster
start-dev:
	kubectl apply -k k8s/overlays/dev
# config-build:
# 	$(EXEC_APP) php artisan config:clear
# 	$(EXEC_APP) php artisan config:cache

# deploy:establish-proxy-network establish-named-volumes start-service   config-build view-cache
deploy-dev:build-image-dev start-dev
skaffold-dev:
	skaffold dev
ingress-pending:
	kubectl label nodes k3d-dev-cluster-server-0 ingress-ready=true --overwrite
ingress-temporary-down:
	kubectl patch validatingwebhookconfiguration ingress-nginx-admission \
		--type='json' \
		-p='[{"op": "replace", "path": "/webhooks/0/failurePolicy", "value": "Ignore"}]'
ingress-up:
	kubectl patch validatingwebhookconfiguration ingress-nginx-admission \
		--type='json' \
		-p='[{"op": "replace", "path": "/webhooks/0/failurePolicy", "value": "Fail"}]'
# 以上指令僅為部署時可使用
# kubectl get secrets 查詢secret
create-secret:
	kubectl create secret generic app-env-secret --from-env-file=.env
get-secret:
	kubectl get secrets
create-cert:
	kubectl create secret tls web-app-certs --cert=certs/cert.pem --key=certs/key.pem
get-cert:
	kubectl describe secret web-app-certs
get-pod:
	kubectl get pods
get-clusters:
	kubectl config get-clusters
create-doorway:
	k3d cluster create my-dev-cluster \
	--servers 1 \
	--agents 2 \
	-p "80:80@loadbalancer" \
	-p "443:443@loadbalancer" \
	--k3s-arg "--disable=traefik@server:0"
install ingress-nginx:
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.7.0/deploy/static/provider/kind/deploy.yaml

# config-rebuild:
# 	$(EXEC_WORK) php artisan config:clear
# 	$(EXEC_WORK) php artisan config:cache
# migrate-fresh:
# 	$(EXEC_WORK) php artisan migrate:fresh --database=migrate_runner --seed
# migrate:
# 	$(EXEC_WORK) php artisan migrate --database=migrate_runner

# dev-config-rebuild:
# 	$(EXEC_WORK_ROOT) php artisan config:clear
# 	$(EXEC_WORK_ROOT) php artisan config:cache
# dev-migrate-fresh:
# 	$(EXEC_WORK_ROOT) php artisan migrate:fresh --database=migrate_runner --seed
# dev-migrate:
# 	$(EXEC_WORK_ROOT) php artisan migrate --database=migrate_runner
