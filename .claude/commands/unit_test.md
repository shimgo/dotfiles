以下の手順に従って、$ARGUMENTS のユニットテストを作成してください。

1. 以下の点を確認し、コードベースを理解する。
  - データベーススキーマ（schema.sqlファイル）を確認する。
  - GraphQLスキーマ（{endpoint}resolver/配下の*.graphqlファイル）を確認する。
  - domain/配下の*_test.goファイルを確認する。
2. テスト関数名を検討する。テスト関数名は、テストする内容に応じて以下のような形式にする。
  - 型のメソッドの場合: `Test_{型名}_{メソッド名}`
  - 関数の場合: `Test_{関数名}`
  - さらに特定領域のテストを実装する場合: 上記の末尾に`_{テストする領域}`を追加する。
3. 以下の点を考慮してテストケースを検討する。
  - 境界値分析を行う。特に配列が空のケースや、オプショナルな引数がnilのケースを必ずテストする。
4. テーブル駆動テストの形式でユニットテストを作成する。以下の形式を基本とする。
  - 人が読み下していくことができるように、冗長でもいいのでできるだけ値を共通化せず、argsやwantsの中に直接記述する。
  - テストケースのテーブル内で構造体を直接初期化する場合、テストに関係するフィールドだけを埋める。
  ```go
  func Test_generateFoo(t *testing.T) {
  	type args struct {
  		arg1 string
  	}
  	type want struct {
  		foo Foo
  	}
  	tests := []struct {
  		name string
  		args args
  		want want
  	}{
  		{
  			name: "Xの場合、Yになること",
  			args: args{
  				arg1: "arg1",
  			},
  			want: want{
  				foo: Foo{
  					field1: "field1",
  				},
  			},
  		},
  	}
  	cmpOpts := []cmp.Option{
  		cmpopts.IgnoreFields(Hoo{}, "ID", "CreatedAt"),
  	}
  	for _, tt := range tests {
  		t.Run(tt.name, func(t *testing.T) {
  			t.Parallel()
  			gotFoo := generateFoo(tt.args.arg1)
  			if diff := cmp.Diff(gotFoo, tt.want.foo); diff != "" {
  				t.Errorf("generateFoo() mismatch (-want +got): %v", diff)
  			}
  		})
  	}
  }
  ```
