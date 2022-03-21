#include < amxmodx >
#include < sqlx >
#include <zombie_plague_special>
#include <zpsp_xp_system>
#include <fvault>
#include <register_system>

#define MAX_CLIENTS     32
#define TASK_LOAD_DATA  123526

///MySQL
#define SQL_HOST        "5.101.153.220" // IP/Host
#define SQL_USER        "snebars_testbd" // Login/User
#define SQL_PASSWORD    "357LGlg@" // Pawssword
#define SQL_DATABASE    "snebars_testbd" // DataBase
#define SQL_TABLENAME   "zpbank_and_lvl" //Sql table name

#define STARTMONEY  50 //start money

new bool: g_bUserLoaded[ MAX_CLIENTS + 1 char ];
new const VAULT_NAME[] = "zpsp_xp_system" //Name file.txt where it saves xp and levels (Check in amxmodx/data/)

new g_szName[ MAX_CLIENTS + 1 ][ 34 ];
new g_szNamenologin[33];
new g_szQuery[512];
new g_iPlayerXP[33], g_iPlayerLevel[33]
new nomer[33]
new on_off[33]
new Handle: g_hDBTuple;
new Handle: g_hConnect;

public plugin_init( )
{
    register_plugin( "zpbank_and_lvl_save_in_mysql", "1.0", "By Robert7791" );
    register_clcmd("logining", "CheckLogAndReg")
}

public plugin_cfg( ) SQL_LoadDebug( ); //Load Mysql
public plugin_end( )
{
    if( g_hDBTuple )
        SQL_FreeHandle( g_hDBTuple );

    if( g_hConnect )
        SQL_FreeHandle( g_hConnect );

    return;
}

public CheckLogAndReg(iPlayer)
{
    if(is_registered(iPlayer) && is_logged(iPlayer))
    {
        on_off[iPlayer] = 1;
        checkplayer(iPlayer);
    }
    else
    {
        on_off[iPlayer] = 0
    }
}

public client_putinserver( iPlayer ) {
    on_off[iPlayer] = 0
    nomer[iPlayer] = 0
    get_user_name(iPlayer, g_szNamenologin[iPlayer], charsmax(g_szNamenologin));
    g_bUserLoaded{ iPlayer } = false;
}

public checkplayer(iPlayer) {
    if ( on_off[iPlayer] == 1 && nomer[iPlayer] == 0) {
    set_task( random_float( 1.0, 3.0 ), "CTask__LoadData", iPlayer +TASK_LOAD_DATA );
    nomer[iPlayer] = 1
    }
    }

public client_disconnected( iPlayer )
{
    //If player didn`t register, don`t save his money and level
    if( !g_bUserLoaded{ iPlayer } || is_user_bot( iPlayer ) ) {
        new szKey[64], szData[256]
        g_iPlayerLevel[iPlayer] = 0;
        g_iPlayerXP[iPlayer] = 0;
        formatex(szKey, charsmax(szKey), "%s-NAME", g_szNamenologin[iPlayer]);
        formatex(szData, charsmax(szData), "%i#%i#", g_iPlayerLevel[iPlayer], g_iPlayerXP[iPlayer]);
        fvault_set_data(VAULT_NAME, szKey, szData);
    }

    if( !g_bUserLoaded{ iPlayer } || is_user_bot( iPlayer ) )
        return;
    //If player registered, save his ammo and level
    new szKey[64], szData[256], szXP[32], szLevel[32];
    formatex(szKey, charsmax(szKey), "%s-NAME", g_szName[ iPlayer ])
    formatex(szData, charsmax(szData), "%i#%i#", g_iPlayerLevel[iPlayer], g_iPlayerXP[iPlayer])
    fvault_get_data(VAULT_NAME, szKey, szData, charsmax(szData))
    replace_string(szData, charsmax(szData), "#", " ")
    parse(szData, szLevel, charsmax(szLevel), szXP, charsmax(szXP))
    g_iPlayerLevel[iPlayer] = str_to_num(szLevel)
    g_iPlayerXP[iPlayer] = str_to_num(szXP)

    formatex( g_szQuery, charsmax( g_szQuery ), "UPDATE `%s` SET `Money` = '%d', `LVL` = '%d', `XP` = '%d' WHERE `%s`.`Name` = '%s';", SQL_TABLENAME, zp_get_user_ammo_packs( iPlayer ) ,g_iPlayerLevel[iPlayer], g_iPlayerXP[iPlayer],  SQL_TABLENAME, g_szName[ iPlayer ] );
    SQL_ThreadQuery( g_hDBTuple, "SQL_ThreadQueryHandler", g_szQuery );

 }

public CTask__LoadData( iTask )
{
    new iPlayer = iTask -TASK_LOAD_DATA;

    if( !is_user_connected( iPlayer ) || is_user_bot( iPlayer ) )
        return;

    new iParams[ 1 ];
    iParams [ 0 ] = iPlayer;

    get_user_name( iPlayer, g_szName[ iPlayer ], charsmax( g_szName[ ] ) );

    formatex( g_szQuery, charsmax( g_szQuery ), "SELECT * FROM `%s` WHERE ( `%s`.`Name` = '%s' )", SQL_TABLENAME, SQL_TABLENAME, g_szName[ iPlayer ] );
    SQL_ThreadQuery( g_hDBTuple, "SQL_QueryConnection", g_szQuery, iParams, sizeof iParams );
}

// MySQL
public SQL_LoadDebug()
{
    new szError[ 512 ];
    new iErrorCode;

    g_hDBTuple = SQL_MakeDbTuple( SQL_HOST, SQL_USER, SQL_PASSWORD, SQL_DATABASE );
    g_hConnect = SQL_Connect( g_hDBTuple, iErrorCode, szError, charsmax( szError ) );

    if( g_hConnect == Empty_Handle )
        set_fail_state( szError );

    if( !SQL_TableExists( g_hConnect, SQL_TABLENAME ) )
    {
        new Handle: hQueries;
        new szQuery[ 512 ];

        formatex( szQuery, charsmax( szQuery ), "CREATE TABLE IF NOT EXISTS `%s` ( id INT(11) NOT NULL AUTO_INCREMENT, `Name` varchar( 32 ) CHARACTER SET cp1250 COLLATE cp1250_general_ci NOT NULL, `Money` INT NOT NULL, `LVL` INT NOT NULL, `XP` INT NOT NULL, PRIMARY KEY(id))", SQL_TABLENAME );
        hQueries = SQL_PrepareQuery( g_hConnect, szQuery );

        if( !SQL_Execute( hQueries ) )
        {
            SQL_QueryError( hQueries, szError, charsmax( szError ) );
            set_fail_state( szError );
        }
        SQL_FreeHandle( hQueries );
    }

}

public SQL_QueryConnection( iState, Handle: hQuery, szError[ ], iErrorCode, iParams[ ], iParamsSize )
{
    switch( iState )
    {
        case TQUERY_CONNECT_FAILED: log_amx( "Load - Could not connect to SQL database. [%d] %s", iErrorCode, szError );
        case TQUERY_QUERY_FAILED: log_amx( "Load Query failed. [%d] %s", iErrorCode, szError );
    }

    new iPlayer = iParams[ 0 ];
    g_bUserLoaded{ iPlayer } = true;

    if( SQL_NumResults( hQuery ) < 1 )
    {
        if( equal( g_szName[ iPlayer ], "ID_PENDING" ) )
            return PLUGIN_HANDLED;

        zp_set_user_ammo_packs( iPlayer, STARTMONEY );

        formatex( g_szQuery, charsmax( g_szQuery ), "INSERT INTO `%s` ( `Name`, `Money`, `LVL`, `XP`) VALUES ( '%s', '%d', '%d','%d');", SQL_TABLENAME, g_szName[ iPlayer ], zp_get_user_ammo_packs( iPlayer ), zp_get_user_level(iPlayer), zp_get_user_xp(iPlayer));
        SQL_ThreadQuery( g_hDBTuple, "SQL_ThreadQueryHandler", g_szQuery );

        return PLUGIN_HANDLED;
    }
    else
    {
        zp_set_user_ammo_packs( iPlayer, SQL_ReadResult( hQuery, 2 ) );
        zp_set_user_level( iPlayer, SQL_ReadResult( hQuery, 3 ) );
        zp_set_user_xp( iPlayer, SQL_ReadResult( hQuery, 4 ) );
    }

    return PLUGIN_HANDLED;
}

public SQL_ThreadQueryHandler( iState, Handle: hQuery, szError[ ], iErrorCode, iParams[ ], iParamsSize )
{
    if( iState == 0 )
        return;

    log_amx( "SQL Error: %d (%s)", iErrorCode, szError );
}

// Stocks
stock bool: SQL_TableExists( Handle: hDataBase, const szTable[ ] )
{
    new Handle: hQuery = SQL_PrepareQuery( hDataBase, "SELECT * FROM information_schema.tables WHERE table_name = '%s' LIMIT 1;", szTable );
    new szError[ 512 ];

    if( !SQL_Execute( hQuery ) )
    {
        SQL_QueryError( hQuery, szError, charsmax( szError ) );
        set_fail_state( szError );
    }
    else if( !SQL_NumResults( hQuery ) )
    {
        SQL_FreeHandle( hQuery );
        return false;
    }

    SQL_FreeHandle( hQuery );
    return true;
}
