<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Mailgun, Postmark, AWS and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'postmark' => [
        'token' => env('POSTMARK_TOKEN'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    'resend' => [
        'key' => env('RESEND_KEY'),
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],

    'rajaongkir' => [
        'base_url' => env('RAJAONGKIR_BASE_URL', 'https://rajaongkir.komerce.id/api/v1'),
        'api_key' => env('RAJAONGKIR_API_KEY'),
        'origin_search' => env('RAJAONGKIR_ORIGIN_SEARCH', 'Tanjung Duren Selatan'),
        'couriers' => array_filter(array_map(
            'trim',
            explode(',', env('RAJAONGKIR_COURIERS', 'jne,jnt,sicepat')),
        )),
    ],

    'shop_bank' => [
        'name' => env('SHOP_BANK_NAME'),
        'account_name' => env('SHOP_BANK_ACCOUNT_NAME'),
        'account_number' => env('SHOP_BANK_ACCOUNT_NUMBER'),
    ],

    'midtrans' => [
        'server_key' => env('MIDTRANS_SERVER_KEY'),
        'client_key' => env('MIDTRANS_CLIENT_KEY'),
        'is_production' => env('MIDTRANS_IS_PRODUCTION', false),
        'finish_url' => env(
            'APP_PAYMENT_RETURN_URL',
            'http://localhost:3000/#/payment-return',
        ),
        'snap_url' => env(
            'MIDTRANS_IS_PRODUCTION',
            false,
        ) ? 'https://app.midtrans.com/snap/v1/transactions' : 'https://app.sandbox.midtrans.com/snap/v1/transactions',
        'api_url' => env(
            'MIDTRANS_IS_PRODUCTION',
            false,
        ) ? 'https://api.midtrans.com/v2' : 'https://api.sandbox.midtrans.com/v2',
    ],

];
