# HTTP APIs

This folder contains `.http` files used by the [VS Code REST Client](https://marketplace.visualstudio.com/items?itemName=humao.rest-client) extension to test Linode (now Akamai) REST APIs.

## VS Code - REST Client Integration

Set your `Linode Token` in `.vscode/settings.json`.
You can edit the following snippet with your token.

```
"rest-client.environmentVariables": {
        "$shared": {
            "linode_token": "xxx"
        }
    }
```
