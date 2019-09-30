#!/bin/bash

path_old=$PATH
d=/mnt/data/optimize-partial-toast

echo version type size len rows randomlen prefix slice run time > results.csv

for s in 100000000 1000000000; do

	for x in master patched; do

		PATH=/var/lib/postgresql/optimize-partial-toast/pg-$x/bin:$path_old

		which pg_ctl

		mkdir -p log/$x/$s

		killall -9 postgres
		rm -Rf $d

		echo `date` "initializing cluster $x $s"
		pg_ctl -D $d init > log/$x/$s/init.log 2>&1

		echo "work_mem = 512MB" >> $d/postgresql.conf
		echo "maintenance_work_mem = 512MB" >> $d/postgresql.conf
		echo "max_parallel_maintenance_workers = 0" >> $d/postgresql.conf
		echo "shared_buffers = 8GB" >> $d/postgresql.conf

		pg_ctl -D $d/ -w -l log/$x/$s/pg.log start

		ps ax > log/$x/$s/ps.log

		for len in 10000 100000 1000000 10000000; do

			rows=$(($s/len))

			for a in 1 10 1000 100000 10000000; do

				if [ "$a" -gt "$len" ]; then
					continue
				fi

				b=$((len - a))

				dropdb --if-exists test > /dev/null 2>&1
				createdb test > /dev/null 2>&1

				psql test -c "create unlogged table t (a text)" > /dev/null 2>&1

				psql test -c "create extension randomstring" > /dev/null 2>&1

				psql test -c "truncate t" > /dev/null 2>&1

				psql test -c "insert into t select random_string($a) || repeat('a', $b) from generate_series(1,$rows) S(i)" > /dev/null 2>&1

				psql test -c "vacuum analyze t" > /dev/null 2>&1

				psql test -c "checkpoint" > /dev/null 2>&1

				for p in 0 10 1000 100000 10000000; do

					if [ "$p" -gt "$len" ]; then
						continue
					fi

					for l in 1 10 1000 100000 10000000; do

						if [ "$l" -gt "$len" ]; then
							continue
						fi

						for r in `seq 1 10`; do

							psql test > tmp.log <<EOF
\timing on
select sum(length(substr(a,$p,$l))) from t
EOF

							t=`cat tmp.log | grep Time | awk '{print $2}'`

							echo $x random-first $s $len $rows $a $p $l $r $t >> results.csv

						done

					done

				done

			done

			for a in 1 10 1000 100000 10000000; do

				if [ "$a" -gt "$len" ]; then
					continue
				fi

				b=$((len - a))

				dropdb --if-exists test > /dev/null 2>&1
				createdb test > /dev/null 2>&1

				psql test -c "create unlogged table t (a text)" > /dev/null 2>&1

				psql test -c "create extension randomstring" > /dev/null 2>&1

				psql test -c "truncate t" > /dev/null 2>&1

				psql test -c "insert into t select repeat('a', $b) || random_string($a) from generate_series(1,$rows) S(i)" > /dev/null 2>&1

				psql test -c "vacuum analyze t" > /dev/null 2>&1

				psql test -c "checkpoint" > /dev/null 2>&1

				for p in 0 10 1000 100000 10000000; do

					if [ "$p" -gt "$len" ]; then
						continue
					fi

                		        for l in 1 10 1000 100000 10000000; do

						if [ "$l" -gt "$len" ]; then
							continue
						fi

						for r in `seq 1 10`; do

							psql test > tmp.log <<EOF
\timing on
select sum(length(substr(a,$p,$l))) from t
EOF

							t=`cat tmp.log | grep Time | awk '{print $2}'`

							echo $x random-last $s $len $rows $a $p $l $r $t >> results.csv

						done

					done

				done

			done

		done

	done

done
