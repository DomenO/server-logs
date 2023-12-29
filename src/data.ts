import {Pool, PoolConfig, PoolConnection, createPool} from 'mariadb';


export class DataManager {

    private pool: Pool;
    private connect: PoolConnection;

    constructor(config: PoolConfig) {
        this.pool = createPool(config);
    }

    async init() {
        this.connect = await this.pool.getConnection();
    }

    async checkAuthData(name: string): Promise<number | null> {
        try {
            const result = await this.connect.query('SELECT id FROM servers.containers WHERE name = ? LIMIT 1', [name]);
            return result.length ? result[0].id : null;

        } catch (err) {
            console.error(err);
            return null;
        }
    }

    async sendAddData(data: {
        container_id: number,
        items: {
            time: number;
            log: string;
        }[]
    }): Promise<boolean> {
        if (!data.items.length) {
            return true;
        }

        try {
            const fields = [
                'container_id',
                'time',
                'log',
            ];

            const selectFields = fields.map(field => `\`${field}\``).join(', ');
            const selectValues = fields.map(() => '?').join(', ');
            const arrSelectValues = `(${selectValues}), `.repeat(data.items.length).slice(0, -2);

            const result = await this.connect.query(
                `INSERT INTO servers.containers_logs(${selectFields}) values ${arrSelectValues}`,
                data.items.map(item => ([
                    data.container_id,
                    item.time,
                    item.log
                ])).flat()
            );

            return Boolean(result);

        } catch (err) {
            console.error(err);
            return false;
        }
    }
}