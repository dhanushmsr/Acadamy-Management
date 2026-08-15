from typing import List
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import select

from app.db import get_db
from app.models import User, Material, MaterialSale, Student
from app.schemas import MaterialCreate, MaterialOut, MaterialSaleCreate, MaterialSaleOut
from app.core.deps import get_current_user

router = APIRouter(prefix="/materials", tags=["Materials"])

@router.get("", response_model=List[MaterialOut])
def get_materials(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not current_user.academy_id:
        raise HTTPException(status_code=403, detail="Not associated with an academy")
    
    materials = db.scalars(
        select(Material).where(Material.academy_id == current_user.academy_id).order_by(Material.name)
    ).all()
    return materials

@router.post("", response_model=MaterialOut, status_code=201)
def create_material(
    payload: MaterialCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not current_user.academy_id:
        raise HTTPException(status_code=403, detail="Not associated with an academy")
    
    material = Material(
        academy_id=current_user.academy_id,
        **payload.model_dump()
    )
    db.add(material)
    db.commit()
    db.refresh(material)
    return material

@router.post("/sell", response_model=MaterialSaleOut, status_code=201)
def sell_material(
    payload: MaterialSaleCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not current_user.academy_id:
        raise HTTPException(status_code=403, detail="Not associated with an academy")
        
    material = db.get(Material, payload.material_id)
    if not material or str(material.academy_id) != str(current_user.academy_id):
        raise HTTPException(status_code=404, detail="Material not found")
        
    if payload.student_id:
        student = db.get(Student, payload.student_id)
        if not student or str(student.academy_id) != str(current_user.academy_id):
            raise HTTPException(status_code=404, detail="Student not found")
            
    if payload.quantity <= 0:
        raise HTTPException(status_code=400, detail="Quantity must be greater than 0")
        
    if material.stock_quantity < payload.quantity:
        raise HTTPException(status_code=400, detail="Not enough stock available")
        
    total_price = material.price * payload.quantity
    material.stock_quantity -= payload.quantity
    
    sale = MaterialSale(
        material_id=payload.material_id,
        student_id=payload.student_id,
        quantity=payload.quantity,
        total_price=total_price
    )
    db.add(sale)
    db.commit()
    db.refresh(sale)
    return sale
