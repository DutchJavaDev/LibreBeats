package main

import (
	"context"
	"errors"
	"fmt"
	"os"
	"strings"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

const ReturningIdParameter = "RETURNING"

var DbInstancePool *pgxpool.Pool

type BaseTable struct {
	Pool *pgxpool.Pool
}

func NewBaseTableInstance() BaseTable {
	return BaseTable{
		Pool: DbInstancePool,
	}
}

func CreateConnectionPool() {
	databaseUrl := os.Getenv("POSTGRES_BACKEND_URL")

	pool, err := pgxpool.New(context.Background(), databaseUrl)
	if err != nil {
		panic(fmt.Sprintf("unable to create connection pool: %v", err))
	}

	// Test connection
	err = pool.Ping(context.Background())
	if err != nil {
		pool.Close()
		panic(fmt.Sprintf("unable to ping database: %v", err))
	}

	DbInstancePool = pool
}

func (base *BaseTable) InsertWithReturningId(query string, params ...any) (lastInsertedId int, err error) {

	if !strings.Contains(query, ReturningIdParameter) {
		return -1, errors.New("Query does not contain RETURNING keyword")
	}

	transaction, err := base.Pool.Begin(context.Background())
	if err != nil {
		return -1, err
	}

	statement, err := transaction.Prepare(context.Background(), "", query)
	if err != nil {
		transaction.Rollback(context.Background())
		return -1, err
	}
	defer transaction.Conn().Close(context.Background())

	err = transaction.QueryRow(context.Background(), statement.SQL, params...).Scan(&lastInsertedId)

	if err != nil {
		transaction.Rollback(context.Background())
		return -1, err
	}

	err = transaction.Commit(context.Background())

	if err != nil {
		transaction.Rollback(context.Background())
		return -1, err
	}

	return lastInsertedId, nil
}

func (base *BaseTable) InsertWithReturningIdUUID(query string, params ...any) (lastInsertedId uuid.UUID, err error) {

	if !strings.Contains(query, ReturningIdParameter) {
		return uuid.Nil, errors.New("Query does not contain RETURNING keyword")
	}

	transaction, err := base.Pool.Begin(context.Background())
	if err != nil {
		return uuid.Nil, err
	}

	statement, err := transaction.Prepare(context.Background(), "", query)
	if err != nil {
		transaction.Rollback(context.Background())
		return uuid.Nil, err
	}
	defer transaction.Conn().Close(context.Background())

	err = transaction.QueryRow(context.Background(), statement.SQL, params...).Scan(&lastInsertedId)

	if err != nil {
		transaction.Rollback(context.Background())
		return uuid.Nil, err
	}

	err = transaction.Commit(context.Background())

	if err != nil {
		transaction.Rollback(context.Background())
		return uuid.Nil, err
	}

	return lastInsertedId, nil
}

func (base *BaseTable) NonScalarQuery(query string, params ...any) (error error) {

	transaction, err := base.Pool.Begin(context.Background())

	if err != nil {
		return err
	}

	defer transaction.Conn().Close(context.Background())

	statement, err := transaction.Prepare(context.Background(), "", query)

	if err != nil {
		transaction.Rollback(context.Background())
		return err
	}

	_, err = transaction.Exec(context.Background(), statement.SQL, params...)

	if err != nil {
		transaction.Rollback(context.Background())
		return err
	}

	err = transaction.Commit(context.Background())

	if err != nil {
		transaction.Rollback(context.Background())
		return err
	}

	return nil
}

func (base *BaseTable) QueryRow(query string, params ...any) (pgx.Row, error) {
	pool, err := base.Pool.Acquire(context.Background())

	if err != nil {
		return nil, err
	}

	return pool.QueryRow(context.Background(), query, params...), nil
}

func (base *BaseTable) QueryRows(query string) (pgx.Rows, error) {
	pool, err := base.Pool.Acquire(context.Background())

	if err != nil {
		return nil, err
	}

	return pool.Query(context.Background(), query, nil)
}
