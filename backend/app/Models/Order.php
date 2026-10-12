<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Order extends Model
{
    protected $fillable = [
        'user_id',
        'code',
        'recipient_name',
        'phone',
        'address',
        'destination_id',
        'destination_label',
        'courier_code',
        'courier_service',
        'shipping_etd',
        'payment_unique_code',
        'midtrans_order_id',
        'midtrans_transaction_id',
        'midtrans_snap_token',
        'midtrans_redirect_url',
        'payment_proof_path',
        'payment_proof_uploaded_at',
        'payment_confirmed_at',
        'payment_confirmed_by',
        'payment_rejection_reason',
        'payment_method',
        'payment_status',
        'status',
        'subtotal',
        'shipping_cost',
        'total',
        'tracking_number',
        'admin_notes',
    ];

    protected function casts(): array
    {
        return [
            'subtotal' => 'decimal:2',
            'shipping_cost' => 'decimal:2',
            'total' => 'decimal:2',
            'payment_proof_uploaded_at' => 'datetime',
            'payment_confirmed_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function items(): HasMany
    {
        return $this->hasMany(OrderItem::class);
    }

    public function paymentConfirmer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'payment_confirmed_by');
    }
}
