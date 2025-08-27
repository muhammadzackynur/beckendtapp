<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CartItem extends Model
{
    use HasFactory;

    /**
     * The table associated with the model.
     *
     * @var string
     */
    protected $table = 'cart_items';

    /**
     * The attributes that are mass assignable.
     *
     * @var array<int, string>
     */
    protected $fillable = [
        'user_id',
        'product_id',
        'quantity',
    ];

    /**
     * Mendefinisikan relasi "belongsTo" ke model Product.
     * Ini memberitahu Laravel bahwa setiap CartItem "milik" satu Product.
     */
    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class);
    }

    /**
     * Mendefinisikan relasi "belongsTo" ke model User.
     * Ini memberitahu Laravel bahwa setiap CartItem "milik" satu User.
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}