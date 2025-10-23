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
  - 価値の低い冗長なテストケースを削減する。例えば、複数の要素を持つ配列から特定の要素を取り出すテストにおいて、先頭・中間・末尾の3ケースをテストする必要はなく、代表として中間の1ケースだけをテストすれば良い。
  - panicを発生する関数について、panicが発生することを検証するテストケースは不要。
4. テーブル駆動テストの形式でユニットテストを作成する。以下の形式を基本とする。
  - テストファイルは、その関数が定義されているファイル名の末尾に `_test.go` を付与した名前にする。
  - 人が読み下していくことができるように、冗長でもいいのでできるだけ値を共通化せず、argsやwantsの中に直接記述する。
  - テストケースのテーブル内で構造体を直接初期化する場合、テストに関係するフィールドだけを埋める。
  - テストに関係するフィールドだけを埋めると言っても、1つのテスト関数の中において、すべてのテストケースで指定するフィールドは統一する。他のテストケースにはフィールドが指定されているのに、あるテストケースだけフィールドが指定されていない、ということがないようにする。
  - 誤ったフィールドの値を返しているのにテストが成功してしまうようなことを防ぐため、1つのテストケース内ではできるだけ同じ値を複数のフィールドで使い回さない。
  - テストケースのnameでは、定義が曖昧な表現を避ける。例えば、「通常のケース」や「正しく動くこと」などは、どんな状態が「通常」や「正しい」のかが曖昧であるため、具体的に記述する。
  - 型のメソッドのテストの例
    ```go
    func Test_Foo_generateBar(t *testing.T) {
    	type args struct {
    		arg1 string
    	}
    	type want struct {
    		bar *Bar
    	}
    	tests := []struct {
    		name string
    		foo *Foo
    		want want
    	}{
    		{
    			name: "Xの場合、Yになること",
    			foo: &Foo{
    				Field1: "field1",
    			},
    			args: args{
    				arg1: "arg1",
    			},
    			want: want{
    				bar: &Bar{
    					Field1: "field1",
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
    			gotBar := tt.foo.generateBar(tt.args.arg1)
    			if diff := cmp.Diff(gotBar, tt.want.bar); diff != "" {
    				t.Errorf("generateBar() mismatch (-want +got): %v", diff)
    			}
    		})
    	}
    }
    ```
  - 関数のテストの例
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
