# mistyfiky's Shopware

## development

### dev

```shell
make install up urls
```

### prod

```shell
export APP_ENV=prod
make build recreate up urls
```

### update

```shell
make build update recreate urls
```

### PhpStorm

```shell
make compose.phpstorm.dev.yml
```

### kaniko

[Authenticating to the Container registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry#authenticating-to-the-container-registry)

```shell
make kaniko
```
