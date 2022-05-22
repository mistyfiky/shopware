# uber shopware

## development

### dev

```shell
make install up urls
```

### prod

```shell
export COMPOSE_FILE=compose.yml:compose.prod.yml
make install up urls
```

### update

```shell
make build update recreate urls
```
