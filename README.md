# golang-docker

Gin と MySQL を使った Album CRUD の Web API です。開発環境は Docker Compose で起動します。

## 環境構築（開発）

### 1. リポジトリを取得

```bash
git clone <リポジトリURL>
cd golang-docker
```

### 2. イメージをビルド

```bash
docker compose build
```

`Dockerfile` の `development` ステージが使われます（Go 1.26 + Air）。

### 3. コンテナを起動

```bash
docker compose up -d
```

起動順序:

1. `db`（MySQL）が healthcheck で Ready になるまで待機
2. `golang` が起動し、Air でアプリをビルド・実行

### 4. 起動確認

```bash
# コンテナの状態
docker compose ps

# Go アプリのログ（Connected! が出れば DB 接続成功）
docker compose logs -f golang
```

ブラウザまたは curl で確認:

```bash
curl http://localhost:8080/
# => {"message":"Hello World!"}

curl http://localhost:8080/albums
# => album テーブルの JSON 一覧
```

### 5. 停止・削除

```bash
# 停止
docker compose down

# 停止 + DB データ（名前付きボリューム）も削除
docker compose down -v
```

## 接続情報

### Go アプリ（コンテナ内 → DB）

`docker-compose.yml` の `environment` で設定されています。ローカルで Go を直接動かす場合は `.env` を参考にしてください（Compose 起動時は compose 側の値が優先されます）。

| 変数 | 値 |
|------|-----|
| `DB_HOST` | `db` |
| `DB_PORT` | `3306` |
| `DB_NAME` | `golang-docker-mysql` |
| `DB_USER` | `USER` |
| `DB_PASSWORD` | `PASSWORD` |

### ホスト（Mac）から MySQL に直接接続

TablePlus や mysql クライアントなどから接続する場合:

| 項目 | 値 |
|------|-----|
| Host | `127.0.0.1` |
| Port | `3307` |
| Database | `golang-docker-mysql` |
| User | `USER` |
| Password | `PASSWORD` |

root で接続する場合: ユーザー `root` / パスワード `root`

## Air

開発時は [Air](https://github.com/air-verse/air) がソースの変更を監視し、自動でビルド・再起動します。設定ファイルはプロジェクト直下の `.air.toml` です。

### このプロジェクトでの使われ方

| 場所 | 内容 |
|------|------|
| `Dockerfile`（development） | `go install github.com/air-verse/air@latest` で Air をインストール |
| `docker-compose.yml` | `command: ["air", "-c", ".air.toml"]` で起動 |
| bind mount | ホストのソースを `/app` にマウント。ホストで保存 → コンテナ内でも即反映 |

### 動作の流れ

1. ホストで `.go` ファイルを保存する
2. bind mount によりコンテナの `/app` も更新される
3. Air が変更を検知する（Docker では `poll = true` でポーリング）
4. `go build -o ./tmp/main .` を実行する
5. 実行中の `./tmp/main` を再起動する

ビルド成果物は `tmp/main` に出力されます（`.gitignore` 対象）。

### `.air.toml` の設定

```toml
root = "."
tmp_dir = "tmp"

[build]
  bin = "./tmp/main"
  cmd = "go build -o ./tmp/main ."
  poll = true
  poll_interval = 500
  delay = 500
  exclude_dir = ["tmp", "vendor", "mysql-data", "requests", "sql"]
  exclude_regex = ["_test\\.go$"]
  include_ext = ["go", "tpl", "tmpl", "html"]
```

| 設定 | 説明 |
|------|------|
| `root` | 監視・ビルドの基準ディレクトリ（コンテナ内では `/app`） |
| `tmp_dir` | ビルド成果物を置くディレクトリ |
| `cmd` / `bin` | ビルドコマンドと実行バイナリのパス |
| `poll` | `true` にするとファイル変更をポーリングで検知。Docker（特に Mac）の bind mount では inotify が効きにくいため有効化 |
| `poll_interval` | ポーリング間隔（ミリ秒） |
| `delay` | 変更検知後、ビルドを始めるまでの待ち時間（ミリ秒） |
| `exclude_dir` | 監視対象外のディレクトリ（`tmp` は再ビルドの無限ループ防止、`sql` などはアプリ再ビルド不要） |
| `exclude_regex` | 監視対象外のファイルパターン（例: `*_test.go`） |
| `include_ext` | 監視する拡張子。これらが変わったときだけ再ビルド |

### 設定ファイルの作成・更新

初めて用意する場合は、プロジェクト直下で次を実行します。

```bash
go install github.com/air-verse/air@latest
air init   # .air.toml が生成される
```

ローカル（コンテナ外）で Air を試す場合:

```bash
air -c .air.toml
```

### ログの確認

再ビルドの様子は Go コンテナのログで確認できます。

```bash
docker compose logs -f golang
```

## API エンドポイント

| メソッド | パス | 説明 |
|----------|------|------|
| GET | `/` | Hello World |
| GET | `/albums` | 一覧取得 |
| GET | `/albums/:id` | 1件取得 |
| POST | `/albums` | 作成 |
| PATCH | `/albums/:id` | 更新 |
| DELETE | `/albums/:id` | 削除 |

## 本番用イメージのビルド

本番向けの軽量イメージ（Alpine + バイナリのみ）を作る場合:

```bash
docker compose -f docker-compose.build.yml build
```

## データベースの初期化

- `album` テーブルの作成
- サンプルレコード 4 件の投入

**注意:** 初期化 SQL は **データディレクトリが空のときだけ** 実行されます。スキーマをやり直す場合は `docker compose down -v` でボリュームを削除してから再起動してください。

## トラブルシューティング

### `golang` がすぐ終了する / DB に繋がらない

- `db` が Healthy か確認: `docker compose ps`
- ログ確認: `docker compose logs db` / `docker compose logs golang`

### ポートが既に使われている

- API: `8080`（`docker-compose.yml` の `ports` を変更可能）
- MySQL（ホスト側）: `3307`

## 開発の流れ（まとめ）

```bash
docker compose build
docker compose up -d
curl http://localhost:8080/albums
# main.go を編集 → 自動で再ビルド
docker compose down    # 終了時
```
