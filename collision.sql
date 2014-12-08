create or replace function getnotcollisionpos(text[]) returns table(id varchar, x float, y float) as $$
declare
	matrix_array alias for $1;
	matrix text[];
	matrix_all_centroid_x float8;
	matrix_all_centroid_y float8;
	rec record;
	rec2 record;
	cu refcursor;
begin
	--div計算結果テンポラリテーブル
	execute 'create temporary table calc_result (id varchar(255),x float,y float);';
	--div衝突計算用テンポラリテーブル
	execute 'create temporary table collision (id varchar(255),geom geometry);';
	--div用ポリゴン作成
	foreach matrix slice 1 in array matrix_array
	loop
		execute 'insert into collision(id,geom) values (''' || matrix[1] || ''', ''polygon((' || matrix[2] || '))'');';
	end loop;
	
	--全divの重心取得
	execute 'select st_x(geom) as matrix_centroid_x,st_y(geom) as matrix_centroid_y from (select st_centroid(st_collect(geom)) as geom from collision) as t0' into rec;
	matrix_all_centroid_x:=rec.matrix_centroid_x;
	matrix_all_centroid_y:=rec.matrix_centroid_y;
	
	--各divが衝突しているかチェック
	foreach matrix slice 1 in array matrix_array
	loop
		open cu for execute 'select id,ST_Intersects(geom,(select st_collect(geom) from collision where id<>''' || matrix[1] || ''')) as intersect from collision where id=''' || matrix[1] || '''';
		loop
			fetch cu into rec;
				if not found then
				exit;
			end if;
			--衝突している場合は外分線上に移動させてupdate
			if rec.intersect=true then
				raise notice 'matrix is intersect(getnotcollisionpos)';
				perform chkcollision(matrix, matrix_all_centroid_x, matrix_all_centroid_y);
			else
				raise notice 'matrix is not intersect(getnotcollisionpos)';
				--衝突していない場合はx,y取得
				execute 'select st_xmin(geom) as x,st_ymin(geom) as y from collision where id=''' || matrix[1] || '''' into rec2;
				execute 'insert into calc_result(id,x,y) values (''' || matrix[1] || ''', ''' || rec2.x || ''', ''' || rec2.y || ''');';
			end if;
		end loop;
		close cu;
	end loop;
	return query select * from calc_result;
end;
$$ language 'plpgsql';



create or replace function chkcollision(text[], float8, float8) returns boolean as $$
declare
	matrix alias for $1;
	matrix_all_centroid_x alias for $2;
	matrix_all_centroid_y alias for $3;
	matrix_centroid_x float8;
	matrix_centroid_y float8;
	m int:=10;
	n int:=1;
	target_x float8;
	target_y float8;
	rec record;
	cu refcursor;
begin
	--重心を取得
	execute 'select st_x(geom) as matrix_centroid_x,st_y(geom) as matrix_centroid_y from (select st_centroid(geom) as geom from collision where id=''' || matrix[1] || ''') as t0' into rec;
	matrix_centroid_x:=rec.matrix_centroid_x;
	matrix_centroid_y:=rec.matrix_centroid_y;
	
	--全divから現divの重心を元に外分線上(m:n)に移動
	target_x=((-n*matrix_all_centroid_x+m*matrix_centroid_x)/(m-n))-matrix_centroid_x;
	target_y=((-n*matrix_all_centroid_y+m*matrix_centroid_y)/(m-n))-matrix_centroid_y;
	execute 'update collision set geom=st_translate(geom,''' || target_x || ''',''' || target_y || ''') where id=''' || matrix[1] || ''';';
	
	--移動後に衝突しているかチェック
	execute 'select id,ST_Intersects(geom,(select st_collect(geom) from collision where id<>''' || matrix[1] || ''')) as intersect from collision where id=''' || matrix[1] || '''' into rec;
	if rec.intersect=true then
		raise notice 'matrix is intersect(chkcollision): id:%, target_x:% target_y:%', matrix[1],target_x,target_y;
		--衝突しなくなるまで再帰
		perform chkcollision(matrix, matrix_all_centroid_x, matrix_all_centroid_y);
	else
		raise notice 'matrix is not intersect(chkcollision)';
		--衝突していない場合はx,y取得
		execute 'select st_xmin(geom) as x,st_ymin(geom) as y from collision where id=''' || matrix[1] || '''' into rec;
		execute 'insert into calc_result(id,x,y) values (''' || matrix[1] || ''', ''' || rec.x || ''', ''' || rec.y || ''');';
		return true;
	end if;
	return false;
end;
$$ language 'plpgsql';

