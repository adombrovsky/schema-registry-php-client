# no buildin rules and variables
MAKEFLAGS =+ -rR --warn-undefined-variables

.PHONY: composer-install composer-update phpstan cs-fixer examples docker run

ifndef CONFLUENT_VERSION
    CONFLUENT_VERSION := latest
endif

ifndef CONFLUENT_NETWORK_SUBNET
    CONFLUENT_NETWORK_SUBNET := 172.68.0.0/24
endif

ifndef SCHEMA_REGISTRY_IPV4
    SCHEMA_REGISTRY_IPV4 := 172.68.0.103
endif

ifndef KAFKA_BROKER_IPV4
    KAFKA_BROKER_IPV4 := 172.68.0.102
endif

ifndef ZOOKEEPER_IPV4
    ZOOKEEPER_IPV4 := 172.68.0.101
endif

ifndef COMPOSER
    COMPOSER := bin/composer.phar
endif

ifndef COMPOSER_VERSION
    COMPOSER_VERSION := 1.7.2
endif

ifndef PHP
    PHP := bin/php
endif

ifndef PHP_VERSION
    PHP_VERSION := 7.1
endif

ifndef XDEBUG_VERSION
    XDEBUG_VERSION := 2.6.1
endif

-include variables.mk
export

docker:
	docker build \
	  --build-arg PHP_VERSION=$(PHP_VERSION) \
	  --build-arg XDEBUG_VERSION=$(XDEBUG_VERSION) \
	  -t schema-registry-client:$(PHP_VERSION) \
	  -f Dockerfile \
	  .

composer-install:
	PHP_VERSION=$(PHP_VERSION) $(PHP) $(COMPOSER) install --no-interaction --no-progress --no-suggest --no-scripts

composer-update:
	PHP_VERSION=$(PHP_VERSION) $(PHP) $(COMPOSER) update --no-interaction --no-progress --no-suggest --no-scripts

phpstan:
	PHP_VERSION=$(PHP_VERSION) $(PHP) vendor/bin/phpstan.phar analyse -l 7 src

cs-fixer:
	PHP_VERSION=$(PHP_VERSION) $(PHP) bin/php-cs-fixer.phar fix --config=.php_cs.dist -v --dry-run \
	  --path-mode=intersection --allow-risky=yes src test

cs-fixer-modify:
	PHP_VERSION=$(PHP_VERSION) $(PHP) bin/php-cs-fixer.phar fix --config=.php_cs.dist -v \
	  --path-mode=intersection --allow-risky=yes src test

phpunit:
	PHP_VERSION=$(PHP_VERSION) $(PHP) vendor/bin/phpunit --exclude-group integration

phpunit-integration:
	PHP_VERSION=$(PHP_VERSION) $(PHP) vendor/bin/phpunit -c phpunit.xml.integration.dist --group integration

coverage:
	mkdir -p build
	PHP_VERSION=$(PHP_VERSION) $(PHP) vendor/bin/phpunit --coverage-clover=build/coverage.clover --coverage-text
	PHP_VERSION=$(PHP_VERSION) $(PHP) bin/ocular.phar code-coverage:upload --format=php-clover \
	  --repository=g/flix-tech/schema-registry-php-client build/coverage.clover

run:
	PHP_VERSION=$(PHP_VERSION) $(PHP) $(ARGS)

ci-local: cs-fixer phpstan phpunit

examples:
	PHP_VERSION=$(PHP_VERSION) $(PHP) examples/*

install-phars:
	curl http://cs.sensiolabs.org/download/php-cs-fixer-v2.phar -o bin/php-cs-fixer.phar -LR -z bin/php-cs-fixer.phar
	chmod a+x bin/php-cs-fixer.phar
	curl https://scrutinizer-ci.com/ocular.phar -o bin/ocular.phar -LR -z bin/ocular.phar
	chmod a+x bin/ocular.phar
	curl https://getcomposer.org/download/$(COMPOSER_VERSION)/composer.phar -o bin/composer.phar -LR -z bin/composer.phar
	chmod a+x bin/composer.phar


platform:
	docker-compose down
	docker-compose up -d
	sleep 15

clean:
	rm -rf build
	docker-compose down

benchmark:
	docker-compose down
	docker-compose up -d
	sleep 15
	PHP_VERSION=$(PHP_VERSION) $(PHP) ./vendor/bin/phpbench run benchmarks/AvroEncodingBench.php --report=aggregate --retry-threshold=5
	docker-compose down
