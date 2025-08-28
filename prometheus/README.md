Prometheus usa un usuario con el uid: 65534 Si te tira el
error que no tiene permisos sobre
`prometheus/queries.active` acá tenés la respuesta:

```shell
chown -R 65534:65534 config
```
