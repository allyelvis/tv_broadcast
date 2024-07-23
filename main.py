from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy

app = Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///content.db'
db = SQLAlchemy(app)

class Content(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(100), nullable=False)
    description = db.Column(db.String(200), nullable=True)
    file_path = db.Column(db.String(100), nullable=False)

@app.route('/upload', methods=['POST'])
def upload_content():
    data = request.json
    new_content = Content(title=data['title'], description=data['description'], file_path=data['file_path'])
    db.session.add(new_content)
    db.session.commit()
    return jsonify({"message": "Content uploaded successfully!"})

@app.route('/contents', methods=['GET'])
def get_contents():
    contents = Content.query.all()
    return jsonify([{"id": content.id, "title": content.title, "description": content.description} for content in contents])

if __name__ == '__main__':
    db.create_all()
    app.run(debug=True)
